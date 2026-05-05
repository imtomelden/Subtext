import Foundation
import Observation
import OSLog
import SwiftUI

/// Top-level app state. One instance lives at the app root and is read by
/// every view via `@Environment(CMSStore.self)`.
///
/// The store holds three disk-backed slices (`splashContent`, `projects`,
/// `siteSettings`) plus original copies so we can diff and discard.
/// Saves go through `FileService`; backups are captured on app close plus
/// forced in destructive flows (`delete` / `restore`).
@Observable
@MainActor
final class CMSStore {
    enum LoadState: Equatable {
        case idle
        /// No security-scoped bookmark yet — show onboarding instead of
        /// touching the filesystem (which would trigger a TCC prompt for
        /// `~/Documents`).
        case awaitingRepoSelection
        case loading
        case loaded
        case failed(String)
    }

    enum ProjectReloadPipelineState: Equatable {
        case idle
        case running(total: Int)
        case partial(completed: Int, total: Int)
        case complete(total: Int)
        case error(String)
    }

    enum SavePipelineState: Equatable {
        case idle
        case running(target: String)
        case complete(target: String)
        case error(target: String, message: String)
    }

    struct PipelineTelemetry: Equatable {
        var reloadRequests: Int = 0
        var reloadSuperseded: Int = 0
        var reloadFailures: Int = 0
        var saveRequests: Int = 0
        var saveSuperseded: Int = 0
        var saveFailures: Int = 0
    }

    // Domain
    var splashContent: SplashContent = .empty
    var projects: [ProjectDocument] = [] {
        didSet { rebuildProjectIndex() }
    }
    var siteSettings: SiteSettings = .default

    // Original on-disk state (used for dirty diffing and Discard).
    private(set) var originalSplash: SplashContent = .empty
    private(set) var originalSite: SiteSettings = .default
    private(set) var originalProjects: [String: ProjectDocument] = [:]

    // UI state
    var loadState: LoadState = .idle
    var projectReloadPipelineState: ProjectReloadPipelineState = .idle
    var savePipelineState: SavePipelineState = .idle
    private(set) var pipelineTelemetry: PipelineTelemetry = .init()
    var toast: ToastMessage?
    var lastError: String?

    /// Last site-health audit issue count (orphans + broken refs + SEO); updated from `SiteHealthSheet`.
    private(set) var siteHealthOpenIssueTotal: Int = 0
    /// File name (`foo.mdx`) of the currently open project. Mutating this
    /// value queues an async write to `.subtext/preferences.json` so the
    /// next launch can land the user back on the same project.
    var selectedProjectFileName: String? {
        didSet {
            guard selectedProjectFileName != oldValue else { return }
            let next = selectedProjectFileName
            schedulePersistRepoPreferences { prefs in
                prefs.lastOpenProjectFileName = next
            }
        }
    }
    var editingSectionID: String?
    var editingCTAID: String?
    var editingBlockID: UUID?
    var editingProjectSourceBlockIDForPanel: UUID?
    /// Set by the command palette to trigger a block insertion in the active
    /// project. ProjectsRootView observes this and clears it after handling.
    var pendingBlockKind: ProjectBlock.Kind? = nil

    /// Most recent reversible action. The UI surfaces this in a toast-style
    /// undo banner; tapping Undo invokes `restore` and clears the entry.
    var pendingUndo: UndoEntry?

    /// Files whose on-disk mtime has changed since we last read them,
    /// *without* Subtext being the author. Surfaced as a banner in the
    /// detail view with one-click reload.
    var externalChanges: Set<URL> = []

    /// When a ⌘S save detects that the file was modified out-of-band
    /// since we read it, we park the save here and let the user pick:
    /// overwrite, reload, or cancel. Drives a `.alert` in `ContentView`.
    var pendingSaveConflict: SaveConflict?

    /// Populated at launch if `.subtext-drafts/` contained autosaved edits
    /// from a prior session. Cleared when the user accepts or discards.
    var pendingRecovery: DraftService.Recovery?

    /// Timestamp of the most recent autosave to `.subtext-drafts/` for the
    /// currently dirty content. `nil` until the first autosave fires after
    /// load. Surfaced in editor toolbars as "Draft saved · Xs ago" so users
    /// can trust the safety net.
    private(set) var lastDraftPersistedAt: Date?

    // Services
    let fileService = FileService()
    let backupService = BackupService()
    let draftService = DraftService()
    let repoSettings = RepoSettingsService()
    let eventLog = EventLog()
    private var watcher: ContentWatcher?
    private var autosaveTask: Task<Void, Never>?
    private var sessionChangedFiles: Set<URL> = []
    private var didFlushSessionBackupsOnClose = false

    /// In-memory mirror of the on-disk per-repo preferences. Loaded once
    /// after the repo selection succeeds, mutated whenever the user
    /// switches projects or tabs, and flushed back to disk through the
    /// `RepoSettingsService` actor.
    private(set) var repoPreferences: RepoPreferences = .empty
    private var repoPreferencesPersistTask: Task<Void, Never>?
    private var projectIndexByFileName: [String: Int] = [:]

    private static let siteHealthIssuesDefaultsKey = "SubtextLastSiteHealthIssueTotal"
    private static let perfLogger = Logger(subsystem: "com.subtext.app", category: "ux.perf")
    private let metricClock = ContinuousClock()

    init() {
        siteHealthOpenIssueTotal = UserDefaults.standard.integer(forKey: Self.siteHealthIssuesDefaultsKey)
        rebuildProjectIndex()
    }

    func recordSiteHealthIssueTotal(_ total: Int) {
        siteHealthOpenIssueTotal = total
        UserDefaults.standard.set(total, forKey: Self.siteHealthIssuesDefaultsKey)
    }

    // MARK: - Per-repo preferences

    /// Reads `.subtext/preferences.json` and applies any values that the
    /// store can restore directly (e.g. last-open project). Tab + UI
    /// state lives in views; they read `repoPreferences` to decide their
    /// initial value.
    private func loadRepoPreferences() async {
        let prefs = await repoSettings.read()
        self.repoPreferences = prefs

        if let last = prefs.lastOpenProjectFileName,
           projects.contains(where: { $0.fileName == last }) {
            self.selectedProjectFileName = last
        }
    }

    /// Coalesce repeated mutations into a single disk write. Most of the
    /// callers (selection changes, tab switches) fire several times
    /// during a single user gesture; we only need the final value to hit
    /// disk.
    private func schedulePersistRepoPreferences(
        _ mutate: @escaping @Sendable (inout RepoPreferences) -> Void
    ) {
        mutate(&repoPreferences)
        repoPreferencesPersistTask?.cancel()
        let snapshot = repoPreferences
        repoPreferencesPersistTask = Task { [repoSettings] in
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            await repoSettings.write(snapshot)
        }
    }

    /// Public entry point for the sidebar — same coalescing semantics.
    func recordSidebarTab(_ tab: SidebarTab) {
        guard repoPreferences.lastSidebarTab != tab.rawValue else { return }
        schedulePersistRepoPreferences { prefs in
            prefs.lastSidebarTab = tab.rawValue
        }
    }

    /// Public entry point so views (e.g. `ProjectEditorView` disclosure
    /// groups) can persist their open/closed state. Keys must be stable
    /// across releases.
    func recordExpandedDisclosure(_ key: String, isExpanded: Bool) {
        var dict = repoPreferences.expandedDisclosures ?? [:]
        if dict[key] == isExpanded { return }
        dict[key] = isExpanded
        let snapshot = dict
        schedulePersistRepoPreferences { prefs in
            prefs.expandedDisclosures = snapshot
        }
    }

    func expandedDisclosure(_ key: String, default fallback: Bool) -> Bool {
        repoPreferences.expandedDisclosures?[key] ?? fallback
    }

    /// Bumped by global actions (e.g. menu bar) so `SiteSettingsView` can present the sheet.
    private(set) var presentEventLogToken: UUID?
    func requestPresentEventLog() {
        presentEventLogToken = UUID()
    }

    func clearPresentEventLogRequest() {
        presentEventLogToken = nil
    }

    // MARK: - Loading

    func loadAll() async {
        let started = metricClock.now
        guard RepoConstants.hasUserSelectedRoot else {
            loadState = .awaitingRepoSelection
            lastError = nil
            recordUXMetric("loadAll.awaitingRepoSelection", started: started)
            return
        }

        loadState = .loading
        lastError = nil

        do {
            async let splashTask = fileService.readSplash()
            async let siteTask = fileService.readSite()
            async let projectsTask = fileService.readAllProjects()

            let splash = try await splashTask
            let site = try await siteTask
            let projects = try await projectsTask

            self.splashContent = splash
            self.originalSplash = splash
            self.siteSettings = site
            self.originalSite = site
            self.projects = projects.sorted(by: Self.projectSortOrder)
            self.originalProjects = Dictionary(uniqueKeysWithValues: projects.map { ($0.fileName, $0) })
            self.externalChanges.removeAll()
            self.loadState = .loaded
            RecentRepos.recordCurrentPrimaryBookmark()
            self.startWatcher()
            self.startAutosave()
            await self.loadRepoPreferences()
            await self.loadDraftRecovery()
            recordUXMetric("loadAll.success", started: started)
        } catch {
            self.loadState = .failed(error.localizedDescription)
            self.lastError = error.localizedDescription
            self.eventLog.append(.error, category: "load", message: error.localizedDescription)
            recordUXMetric("loadAll.failed", started: started, metadata: error.localizedDescription)
        }
    }

    // MARK: - External-change watching

    private func startWatcher() {
        let paths = allWatchedPaths()
        if let existing = watcher {
            existing.replaceWatched(paths)
            return
        }
        let w = ContentWatcher { [weak self] changed in
            self?.handleExternalChanges(changed)
        }
        w.start(paths: paths)
        watcher = w
    }

    private func allWatchedPaths() -> [URL] {
        var paths: [URL] = [RepoConstants.splashFile, RepoConstants.siteFile]
        paths.append(contentsOf: projects.map { projectURL(for: $0.fileName) })
        return paths
    }

    private func refreshWatchedSet() {
        watcher?.replaceWatched(allWatchedPaths())
    }

    private func handleExternalChanges(_ changed: Set<URL>) {
        externalChanges.formUnion(changed)
    }

    func dismissExternalChange(_ url: URL) {
        externalChanges.remove(url)
    }

    /// Reload any file flagged by the watcher from disk, discarding any
    /// in-memory edits the user hasn't saved yet.
    func reloadExternalChange(_ url: URL) async {
        let splash = RepoConstants.splashFile
        let site = RepoConstants.siteFile
        if url == splash {
            await reloadSplash()
        } else if url == site {
            await reloadSite()
        } else if url.path(percentEncoded: false)
            .hasPrefix(RepoConstants.projectsDirectory.path(percentEncoded: false))
        {
            await reloadProject(at: url)
        }
        externalChanges.remove(url)
        watcher?.acknowledgeOwnWrite(url)
    }

    func reloadAllExternalChanges() async {
        let changes = externalChanges
        for url in changes {
            await reloadExternalChange(url)
        }
    }

    // MARK: - Save-conflict detection

    struct SaveConflict: Identifiable, Equatable {
        let id: UUID = UUID()
        let kind: Kind
        let fileURL: URL
        var displayName: String { fileURL.lastPathComponent }

        enum Kind: Equatable {
            case splash
            case site
            case project(fileName: String)
        }
    }

    /// Returns `true` when the file on disk has been modified since we
    /// last read or saved it. Used as the guard in front of every write.
    private func detectsExternalModification(at url: URL) -> Bool {
        guard let known = watcher?.knownMtime(for: url) else { return false }
        let current = ContentWatcher.modDate(of: url)
        // Treat a 1-second-or-smaller delta as "same" — HFS/APFS rounds
        // mtimes and atomic replace-item can advance by sub-second amounts
        // under our own writes.
        return abs(current.timeIntervalSince(known)) > 1
    }

    func confirmOverwrite() async {
        guard let conflict = pendingSaveConflict else { return }
        pendingSaveConflict = nil
        switch conflict.kind {
        case .splash:
            await performSaveSplash(force: true)
        case .site:
            await performSaveSite(force: true)
        case .project(let fileName):
            await performSaveProject(fileName, force: true)
        }
    }

    func reloadFromDisk() async {
        guard let conflict = pendingSaveConflict else { return }
        pendingSaveConflict = nil
        switch conflict.kind {
        case .splash: await reloadSplash()
        case .site: await reloadSite()
        case .project(let fileName):
            await reloadProject(fileName: fileName)
        }
        externalChanges.remove(conflict.fileURL)
    }

    func cancelConflict() {
        pendingSaveConflict = nil
    }

    private func projectURL(for fileName: String) -> URL {
        RepoConstants.projectsDirectory
            .appending(path: fileName, directoryHint: .notDirectory)
    }

    // MARK: - Autosave drafts

    private func startAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                await self.persistDraftsIfDirty()
            }
        }
    }

    /// Write the currently-dirty slices to `.subtext-drafts/`. Clears
    /// each slice's draft once the user saves the real file.
    func persistDraftsIfDirty() async {
        var didPersistAny = false
        if isSplashDirty {
            try? await draftService.writeSplashDraft(splashContent)
            didPersistAny = true
        } else {
            await draftService.clearSplashDraft()
        }
        if isSiteDirty {
            try? await draftService.writeSiteDraft(siteSettings)
            didPersistAny = true
        } else {
            await draftService.clearSiteDraft()
        }
        for doc in projects {
            if isProjectDirty(doc.fileName) {
                try? await draftService.writeProjectDraft(doc)
                didPersistAny = true
            } else {
                await draftService.clearProjectDraft(fileName: doc.fileName)
            }
        }
        if didPersistAny {
            lastDraftPersistedAt = Date()
        }
    }

    private func loadDraftRecovery() async {
        let recovery = await draftService.recover()
        guard !recovery.isEmpty else { return }

        // Only surface drafts that actually differ from what's on disk —
        // a draft identical to the on-disk file is a leftover from a prior
        // successful save and can be safely discarded.
        var filtered = recovery
        if filtered.splash == originalSplash { filtered.splash = nil }
        if filtered.site == originalSite { filtered.site = nil }
        filtered.projects = filtered.projects.filter { doc in
            originalProjects[doc.fileName] != doc
        }

        if filtered.isEmpty {
            await draftService.clearAll()
            return
        }

        pendingRecovery = filtered
    }

    /// Apply recovered drafts into in-memory state. The user then sees the
    /// edits as unsaved and can ⌘S to persist or ⌘⇧Z to discard.
    func acceptRecovery() {
        guard let recovery = pendingRecovery else { return }
        if let splash = recovery.splash { splashContent = splash }
        if let site = recovery.site { siteSettings = site }
        for doc in recovery.projects {
            if let idx = projects.firstIndex(where: { $0.fileName == doc.fileName }) {
                projects[idx] = doc
            } else {
                projects.append(doc)
            }
        }
        projects.sort(by: Self.projectSortOrder)
        pendingRecovery = nil
        showToast("Recovered \(recovery.count) draft\(recovery.count == 1 ? "" : "s")")
    }

    func discardRecovery() async {
        pendingRecovery = nil
        await draftService.clearAll()
    }

    private static func projectSortOrder(_ lhs: ProjectDocument, _ rhs: ProjectDocument) -> Bool {
        // Newest first, with drafts last.
        if lhs.frontmatter.draft != rhs.frontmatter.draft {
            return !lhs.frontmatter.draft
        }
        return lhs.frontmatter.date > rhs.frontmatter.date
    }

    // MARK: - Dirty tracking

    var isSplashDirty: Bool { splashContent != originalSplash }
    var isSiteDirty: Bool { siteSettings != originalSite }

    func isProjectDirty(_ fileName: String) -> Bool {
        guard let idx = projectIndexByFileName[fileName], projects.indices.contains(idx) else { return false }
        let current = projects[idx]
        guard let original = originalProjects[fileName] else { return true }
        return current != original
    }

    var anyProjectDirty: Bool {
        projects.contains { isProjectDirty($0.fileName) }
    }

    /// Number of projects with unsaved edits — drives the Projects sidebar badge.
    var dirtyProjectCount: Int {
        projects.reduce(0) { $0 + (isProjectDirty($1.fileName) ? 1 : 0) }
    }

    /// Total dirty-entity count for the given tab, used by sidebar badges.
    /// Home and Settings are single-entity so they're 0 or 1.
    func dirtyCount(for tab: SidebarTab) -> Int {
        switch tab {
        case .home: isSplashDirty ? 1 : 0
        case .projects: dirtyProjectCount
        case .settings: isSiteDirty ? 1 : 0
        }
    }

    var isAnyDirty: Bool { isSplashDirty || isSiteDirty || anyProjectDirty }

    /// Dirty state relevant to a given sidebar selection.
    func isDirty(for tab: SidebarTab) -> Bool {
        switch tab {
        case .home: isSplashDirty
        case .projects:
            if let file = selectedProjectFileName {
                isProjectDirty(file)
            } else {
                anyProjectDirty
            }
        case .settings: isSiteDirty
        }
    }

    // MARK: - Saving

    func saveSplash() async {
        await performSaveSplash(force: false)
    }

    private func performSaveSplash(force: Bool) async {
        let url = RepoConstants.splashFile
        beginSaveRequest(target: "splash")
        savePipelineState = .running(target: "splash")
        if !force, detectsExternalModification(at: url) {
            pendingSaveConflict = SaveConflict(kind: .splash, fileURL: url)
            savePipelineState = .error(target: "splash", message: "External modification conflict")
            pipelineTelemetry.saveFailures += 1
            return
        }
        do {
            try await fileService.writeSplash(splashContent)
            originalSplash = splashContent
            markSessionChangedFile(url)
            watcher?.acknowledgeOwnWrite(url)
            externalChanges.remove(url)
            showToast("Saved splash.json")
            savePipelineState = .complete(target: "splash")
        } catch {
            showError(error)
            savePipelineState = .error(target: "splash", message: error.localizedDescription)
            pipelineTelemetry.saveFailures += 1
        }
    }

    func saveSite() async {
        await performSaveSite(force: false)
    }

    private func performSaveSite(force: Bool) async {
        let url = RepoConstants.siteFile
        beginSaveRequest(target: "site")
        savePipelineState = .running(target: "site")
        if !force, detectsExternalModification(at: url) {
            pendingSaveConflict = SaveConflict(kind: .site, fileURL: url)
            savePipelineState = .error(target: "site", message: "External modification conflict")
            pipelineTelemetry.saveFailures += 1
            return
        }
        do {
            try await fileService.writeSite(siteSettings)
            originalSite = siteSettings
            markSessionChangedFile(url)
            watcher?.acknowledgeOwnWrite(url)
            externalChanges.remove(url)
            showToast("Saved site.json")
            savePipelineState = .complete(target: "site")
        } catch {
            showError(error)
            savePipelineState = .error(target: "site", message: error.localizedDescription)
            pipelineTelemetry.saveFailures += 1
        }
    }

    func saveProject(_ fileName: String) async {
        await performSaveProject(fileName, force: false)
    }

    private func performSaveProject(_ fileName: String, force: Bool) async {
        beginSaveRequest(target: fileName)
        savePipelineState = .running(target: fileName)
        guard let doc = projects.first(where: { $0.fileName == fileName }) else {
            savePipelineState = .error(target: fileName, message: "Project not found in memory")
            pipelineTelemetry.saveFailures += 1
            return
        }
        let validationIssues = ProjectValidator.validate(doc)
        if !validationIssues.isEmpty {
            let summary = validationIssues
                .prefix(4)
                .map(\.message)
                .joined(separator: " ")
            showError("Cannot save \(fileName): \(summary)")
            savePipelineState = .error(target: fileName, message: summary)
            pipelineTelemetry.saveFailures += 1
            return
        }
        let url = projectURL(for: fileName)
        if !force, detectsExternalModification(at: url) {
            pendingSaveConflict = SaveConflict(
                kind: .project(fileName: fileName),
                fileURL: url
            )
            savePipelineState = .error(target: fileName, message: "External modification conflict")
            pipelineTelemetry.saveFailures += 1
            return
        }
        do {
            try await fileService.writeProject(doc, to: url)
            originalProjects[fileName] = doc
            markSessionChangedFile(url)
            watcher?.acknowledgeOwnWrite(url)
            externalChanges.remove(url)
            showToast("Saved \(doc.frontmatter.title)")
            savePipelineState = .complete(target: fileName)
        } catch {
            showError(error)
            savePipelineState = .error(target: fileName, message: error.localizedDescription)
            pipelineTelemetry.saveFailures += 1
        }
    }

    func saveCurrent(for tab: SidebarTab) async {
        let started = metricClock.now
        beginSaveRequest(target: tab.rawValue)
        savePipelineState = .running(target: tab.rawValue)
        switch tab {
        case .home: await saveSplash()
        case .settings: await saveSite()
        case .projects:
            if let file = selectedProjectFileName {
                await saveProject(file)
            } else {
                for doc in projects where isProjectDirty(doc.fileName) {
                    await saveProject(doc.fileName)
                }
            }
        }
        recordUXMetric("saveCurrent.\(tab.rawValue)", started: started)
        switch savePipelineState {
        case .error:
            break
        default:
            savePipelineState = .complete(target: tab.rawValue)
        }
    }

    // MARK: - Discard

    func discardSplash() {
        splashContent = originalSplash
        editingSectionID = nil
        editingCTAID = nil
    }

    func discardSite() {
        siteSettings = originalSite
    }

    func discardProject(_ fileName: String) {
        guard let original = originalProjects[fileName] else { return }
        guard let idx = projects.firstIndex(where: { $0.fileName == fileName }) else { return }
        projects[idx] = original
        editingBlockID = nil
    }

    func discardCurrent(for tab: SidebarTab) {
        switch tab {
        case .home: discardSplash()
        case .settings: discardSite()
        case .projects:
            if let file = selectedProjectFileName {
                discardProject(file)
            } else {
                for doc in projects where isProjectDirty(doc.fileName) {
                    discardProject(doc.fileName)
                }
            }
        }
    }

    // MARK: - Mutations: Sections

    func addSection(option: SplashSection.AddSectionOption) {
        let section = SplashSection.newDraft(option: option)
        splashContent.sections.append(section)
        editingSectionID = section.id
    }

    func deleteSection(id: String) {
        guard let idx = splashContent.sections.firstIndex(where: { $0.id == id }) else { return }
        let removed = splashContent.sections.remove(at: idx)
        if editingSectionID == id { editingSectionID = nil }
        offerUndo(label: "Deleted \(removed.heading.isEmpty ? "section" : removed.heading)") { [weak self] in
            guard let self else { return }
            let safeIdx = min(idx, self.splashContent.sections.count)
            self.splashContent.sections.insert(removed, at: safeIdx)
        }
    }

    func moveSection(from source: IndexSet, to destination: Int) {
        splashContent.sections.move(fromOffsets: source, toOffset: destination)
    }

    func binding(forSection id: String) -> Binding<SplashSection>? {
        guard let idx = splashContent.sections.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.splashContent.sections[idx] },
            set: { self.splashContent.sections[idx] = $0 }
        )
    }

    // MARK: - Mutations: CTAs

    func addCTA() {
        let cta = SplashCTA.newDraft()
        splashContent.ctas.append(cta)
        editingCTAID = cta.id
    }

    func deleteCTA(id: String) {
        guard let idx = splashContent.ctas.firstIndex(where: { $0.id == id }) else { return }
        let removed = splashContent.ctas.remove(at: idx)
        if editingCTAID == id { editingCTAID = nil }
        offerUndo(label: "Deleted \(removed.name.isEmpty ? "CTA" : removed.name)") { [weak self] in
            guard let self else { return }
            let safeIdx = min(idx, self.splashContent.ctas.count)
            self.splashContent.ctas.insert(removed, at: safeIdx)
        }
    }

    func moveCTA(from source: IndexSet, to destination: Int) {
        splashContent.ctas.move(fromOffsets: source, toOffset: destination)
    }

    func binding(forCTA id: String) -> Binding<SplashCTA>? {
        guard let idx = splashContent.ctas.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.splashContent.ctas[idx] },
            set: { self.splashContent.ctas[idx] = $0 }
        )
    }

    // MARK: - Mutations: Projects

    func createProject(slug: String, title: String, ownership: ProjectFrontmatter.Ownership) async {
        let slug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else { return }
        let fileName = "\(slug).mdx"
        if projects.contains(where: { $0.fileName == fileName }) {
            showError("A project with that slug already exists.")
            return
        }
        let front = ProjectFrontmatter.newDraft(slug: slug, title: title, ownership: ownership)
        let doc = ProjectDocument(
            fileName: fileName,
            frontmatter: front,
            body: "Write your case study here.\n"
        )
        let url = RepoConstants.projectsDirectory.appending(path: fileName, directoryHint: .notDirectory)
        do {
            try await fileService.writeProject(doc, to: url)
            projects.append(doc)
            projects.sort(by: Self.projectSortOrder)
            originalProjects[fileName] = doc
            markSessionChangedFile(url)
            selectedProjectFileName = fileName
            refreshWatchedSet()
            watcher?.acknowledgeOwnWrite(url)
            showToast("Created \(title)")
        } catch {
            showError(error)
        }
    }


    func duplicateProject(_ source: ProjectDocument) async {
        var front = source.frontmatter
        front.draft = true
        front.blocks = front.blocks.map { $0.duplicated() }

        var candidateSlug = source.frontmatter.slug + "-copy"
        var counter = 1
        while projects.contains(where: { $0.frontmatter.slug == candidateSlug }) {
            candidateSlug = "\(source.frontmatter.slug)-copy-\(counter)"
            counter += 1
        }
        front.slug = candidateSlug

        let fileName = "\(candidateSlug).mdx"
        guard !projects.contains(where: { $0.fileName == fileName }) else {
            showError("A project with that filename already exists.")
            return
        }

        let doc = ProjectDocument(fileName: fileName, frontmatter: front, body: source.body)
        let url = RepoConstants.projectsDirectory.appending(path: fileName, directoryHint: .notDirectory)
        do {
            try await fileService.writeProject(doc, to: url)
            projects.append(doc)
            projects.sort(by: Self.projectSortOrder)
            originalProjects[fileName] = doc
            markSessionChangedFile(url)
            selectedProjectFileName = fileName
            refreshWatchedSet()
            watcher?.acknowledgeOwnWrite(url)
            showToast("Duplicated \"\(source.frontmatter.title)\"")
        } catch {
            showError(error)
        }
    }

    func setProjectArchived(_ fileName: String, archived: Bool) async {
        guard let idx = projectIndexByFileName[fileName], projects.indices.contains(idx) else { return }
        projects[idx].frontmatter.archived = archived
        await saveProject(fileName)
        showToast(archived ? "Archived project" : "Unarchived project")
    }

    func deleteProject(_ fileName: String) async {
        let url = RepoConstants.projectsDirectory.appending(path: fileName, directoryHint: .notDirectory)
        do {
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                try await backupService.createBackup(for: url)
            }
            try await fileService.deleteProject(at: url)
            projects.removeAll { $0.fileName == fileName }
            originalProjects.removeValue(forKey: fileName)
            externalChanges.remove(url)
            refreshWatchedSet()
            if selectedProjectFileName == fileName { selectedProjectFileName = nil }
            showToast("Deleted project")
        } catch {
            showError(error)
        }
    }

    func binding(forProject fileName: String) -> Binding<ProjectDocument>? {
        guard let idx = projectIndexByFileName[fileName], projects.indices.contains(idx) else { return nil }
        return Binding(
            get: { self.projects[idx] },
            set: { self.projects[idx] = $0 }
        )
    }

    // MARK: - Restore

    func restoreSplash(from backup: URL) async {
        await restore(backup: backup, to: RepoConstants.splashFile) {
            await self.reloadSplash()
        }
    }

    func restoreSite(from backup: URL) async {
        await restore(backup: backup, to: RepoConstants.siteFile) {
            await self.reloadSite()
        }
    }

    func restoreProject(fileName: String, from backup: URL) async {
        let url = RepoConstants.projectsDirectory.appending(path: fileName, directoryHint: .notDirectory)
        await restore(backup: backup, to: url) {
            await self.reloadProjects()
        }
    }

    private func restore(
        backup: URL,
        to target: URL,
        onComplete: () async -> Void
    ) async {
        do {
            try await backupService.restore(backup: backup, to: target)
            await onComplete()
            showToast("Restored from backup")
        } catch {
            showError(error)
        }
    }

    func reloadSplash() async {
        do {
            let splash = try await fileService.readSplash()
            splashContent = splash
            originalSplash = splash
            watcher?.acknowledgeOwnWrite(RepoConstants.splashFile)
            externalChanges.remove(RepoConstants.splashFile)
        } catch {
            showError(error)
        }
    }

    func reloadSite() async {
        do {
            let site = try await fileService.readSite()
            siteSettings = site
            originalSite = site
            watcher?.acknowledgeOwnWrite(RepoConstants.siteFile)
            externalChanges.remove(RepoConstants.siteFile)
        } catch {
            showError(error)
        }
    }

    func reloadProjects() async {
        let started = metricClock.now
        beginReloadRequest(target: "all")
        projectReloadPipelineState = .running(total: projects.count)
        var completed = 0
        do {
            let docs = try await fileService.readAllProjects()
            let total = max(docs.count, 1)
            projects = docs.sorted(by: Self.projectSortOrder)
            originalProjects = Dictionary(uniqueKeysWithValues: docs.map { ($0.fileName, $0) })
            refreshWatchedSet()
            for doc in docs {
                let url = projectURL(for: doc.fileName)
                watcher?.acknowledgeOwnWrite(url)
                externalChanges.remove(url)
                completed += 1
                projectReloadPipelineState = .partial(completed: completed, total: total)
            }
            if docs.isEmpty {
                projectReloadPipelineState = .complete(total: 0)
            } else {
                projectReloadPipelineState = .complete(total: docs.count)
            }
            recordUXMetric("reloadProjects.success", started: started, metadata: "\(docs.count) docs")
        } catch {
            showError(error)
            projectReloadPipelineState = .error(error.localizedDescription)
            pipelineTelemetry.reloadFailures += 1
            recordUXMetric("reloadProjects.failed", started: started, metadata: error.localizedDescription)
        }
    }

    func reloadProject(fileName: String) async {
        let url = projectURL(for: fileName)
        await reloadProject(at: url)
    }

    /// Incremental reload path for a single changed project file.
    /// Avoids broad project rescans for watcher-driven external edits.
    func reloadProject(at url: URL) async {
        let started = metricClock.now
        let fileName = url.lastPathComponent
        beginReloadRequest(target: fileName)
        projectReloadPipelineState = .running(total: 1)

        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            projects.removeAll { $0.fileName == fileName }
            originalProjects.removeValue(forKey: fileName)
            if selectedProjectFileName == fileName {
                selectedProjectFileName = nil
            }
            refreshWatchedSet()
            watcher?.acknowledgeOwnWrite(url)
            externalChanges.remove(url)
            projectReloadPipelineState = .complete(total: 1)
            recordUXMetric("reloadProject.deleted", started: started, metadata: fileName)
            return
        }

        do {
            let doc = try await fileService.readProject(at: url)
            if let idx = projectIndexByFileName[fileName], projects.indices.contains(idx) {
                projects[idx] = doc
            } else {
                projects.append(doc)
            }
            projects.sort(by: Self.projectSortOrder)
            originalProjects[fileName] = doc
            refreshWatchedSet()
            watcher?.acknowledgeOwnWrite(url)
            externalChanges.remove(url)
            projectReloadPipelineState = .complete(total: 1)
            recordUXMetric("reloadProject.success", started: started, metadata: fileName)
        } catch {
            showError(error)
            projectReloadPipelineState = .error("\(fileName): \(error.localizedDescription)")
            pipelineTelemetry.reloadFailures += 1
            recordUXMetric("reloadProject.failed", started: started, metadata: "\(fileName): \(error.localizedDescription)")
        }
    }

    // MARK: - Undo

    /// One-shot reversible action offered after destructive operations.
    /// Automatically cleared after a short window so the banner doesn't
    /// linger once the user has moved on.
    struct UndoEntry: Identifiable {
        let id: UUID = UUID()
        let label: String
        let restore: @MainActor () -> Void
    }

    private var undoClearTask: Task<Void, Never>?

    func offerUndo(label: String, restore: @escaping @MainActor () -> Void) {
        pendingUndo = UndoEntry(label: label, restore: restore)
        undoClearTask?.cancel()
        undoClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.pendingUndo = nil
        }
    }

    func performUndo() {
        guard let entry = pendingUndo else { return }
        entry.restore()
        pendingUndo = nil
        undoClearTask?.cancel()
    }

    func dismissUndo() {
        pendingUndo = nil
        undoClearTask?.cancel()
    }

    // MARK: - Toasts & errors

    private func showToast(_ text: String) {
        // Do not replace a visible error toast with a success message.
        if toast?.kind == .error { return }
        toast = ToastMessage(text: text, kind: .success)
        lastError = nil
        eventLog.append(.info, category: "toast", message: text)
    }

    private func showError(_ error: Error) {
        showError(error.localizedDescription)
    }

    private func showError(_ message: String) {
        toast = ToastMessage(text: message, kind: .error)
        lastError = message
        eventLog.append(.error, category: "error", message: message)
    }

    // MARK: - UX/perf instrumentation

    /// Records a single latency sample in the in-app event log and unified OS log.
    /// Phase 0 uses this to establish baseline timings before behavior changes.
    func recordUXMetric(_ name: String, started: ContinuousClock.Instant, metadata: String? = nil) {
        let elapsed = metricClock.now - started
        let elapsedMs = elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000
        let message = if let metadata, !metadata.isEmpty {
            "\(name): \(elapsedMs)ms (\(metadata))"
        } else {
            "\(name): \(elapsedMs)ms"
        }
        eventLog.append(.info, category: "ux.perf", message: message)
        Self.perfLogger.info("\(message, privacy: .public)")
    }

    /// Records a non-latency UX telemetry event.
    func recordUXEvent(_ name: String, metadata: String? = nil) {
        let message = if let metadata, !metadata.isEmpty {
            "\(name) (\(metadata))"
        } else {
            name
        }
        eventLog.append(.info, category: "ux.event", message: message)
        Self.perfLogger.info("\(message, privacy: .public)")
    }

    private func beginReloadRequest(target: String) {
        pipelineTelemetry.reloadRequests += 1
        if case .running = projectReloadPipelineState {
            pipelineTelemetry.reloadSuperseded += 1
            recordUXEvent("reload.coalesce.superseded", metadata: target)
        } else {
            recordUXEvent("reload.coalesce.queued", metadata: target)
        }
    }

    private func beginSaveRequest(target: String) {
        pipelineTelemetry.saveRequests += 1
        if case .running = savePipelineState {
            pipelineTelemetry.saveSuperseded += 1
            recordUXEvent("save.coalesce.superseded", metadata: target)
        } else {
            recordUXEvent("save.coalesce.queued", metadata: target)
        }
    }

    // MARK: - Session-end backups

    private func markSessionChangedFile(_ url: URL) {
        sessionChangedFiles.insert(url)
    }

    private func rebuildProjectIndex() {
        projectIndexByFileName = Dictionary(
            uniqueKeysWithValues: projects.enumerated().map { ($0.element.fileName, $0.offset) }
        )
    }

    /// Create one backup per file changed in this session.
    /// This is intended for app/window close and runs once.
    func flushSessionBackupsOnClose() async {
        guard !didFlushSessionBackupsOnClose else { return }
        didFlushSessionBackupsOnClose = true
        guard RepoConstants.hasUserSelectedRoot else { return }

        let changed = sessionChangedFiles.sorted {
            $0.path(percentEncoded: false) < $1.path(percentEncoded: false)
        }
        guard !changed.isEmpty else { return }

        var failed: [String] = []
        for url in changed {
            do {
                try await backupService.createBackup(for: url)
            } catch {
                failed.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        sessionChangedFiles.removeAll()

        if !failed.isEmpty {
            eventLog.append(
                .error,
                category: "backup",
                message: "Session-close backup failures: \(failed.joined(separator: " | "))"
            )
        }
    }
}

// MARK: - Supporting types

enum SidebarTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case projects
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: "Home"
        case .projects: "Projects"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .projects: "folder.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable, Sendable {
    enum Kind: Sendable { case success, error }
    let id: UUID = UUID()
    var text: String
    var kind: Kind
}
