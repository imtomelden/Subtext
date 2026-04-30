import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(CMSStore.self) private var store
    @Environment(DevServerController.self) private var devServer
    @Environment(GitController.self) private var git
    @Environment(\.openWindow) private var openWindow
    @AppStorage("SubtextContentDensityCompact") private var useCompactDensity = false
    @AppStorage("SubtextAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @State private var tab: SidebarTab = .home
    @State private var didApplyInitialTab = false
    @State private var activeModal: ActiveModal?
    @State private var pendingModal: ActiveModal?
    @State private var lastPaletteModalRequestAt: Date = .distantPast
    @State private var lastPaletteModalMode: CommandPalette.Mode?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var repoSelectionError: String?

    var body: some View {
        @Bindable var store = store

        Group {
            if case .awaitingRepoSelection = store.loadState {
                RepoOnboardingView()
                    .frame(minWidth: 700)
                    .background {
                        GlassSurface(prominence: .regular, cornerRadius: 0) { Color.clear }
                            .ignoresSafeArea()
                    }
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(selection: $tab)
                        .navigationSplitViewColumnWidth(
                            min: RepoConstants.sidebarWidth,
                            ideal: RepoConstants.sidebarWidth,
                            max: RepoConstants.sidebarWidth + 72
                        )
                } detail: {
                    ZStack {
                        switch store.loadState {
                        case .idle, .loading:
                            LoadingStateView()
                        case .failed(let message):
                            LoadFailedView(
                                message: message,
                                onRetry: { Task { await store.loadAll() } },
                                onPickDifferentFolder: {
                                    pickDifferentFolder(store: store)
                                }
                            )
                        case .loaded:
                            loadedDetail
                        case .awaitingRepoSelection:
                            // Handled by the outer Group; this branch can't
                            // fire but keeps the switch exhaustive.
                            EmptyView()
                        }
                    }
                    .frame(minWidth: 700)
                    .background {
                        GlassSurface(prominence: .regular, cornerRadius: 0) { Color.clear }
                            .ignoresSafeArea()
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .environment(\.contentDensity, useCompactDensity ? .compact : .comfortable)
        .preferredColorScheme(appAppearanceMode.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .subtextSave)) { _ in
            Task { await store.saveCurrent(for: tab) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextDiscard)) { _ in
            store.discardCurrent(for: tab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextOpenPreview)) { _ in
            openWindow(id: "subtext-preview")
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextOpenPalette)) { note in
            let started = ContinuousClock().now
            let mode = (note.object as? CommandPalette.Mode) ?? .navigate
            guard !shouldSuppressPaletteOpenRequest(for: mode) else { return }
            requestModal(.palette(mode))
            lastPaletteModalRequestAt = Date()
            lastPaletteModalMode = mode
            store.recordUXMetric("palette.open.requested", started: started, metadata: mode.rawValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextToggleFocusMode)) { _ in
            columnVisibility = columnVisibility == .detailOnly ? .automatic : .detailOnly
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextOpenKeyboardShortcuts)) { _ in
            requestModal(.keyboardShortcuts)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextOpenEventLog)) { _ in
            tab = .settings
            store.requestPresentEventLog()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextAppWillTerminate)) { _ in
            Task {
                await store.flushSessionBackupsOnClose()
                await devServer.shutdownForQuit()
            }
        }
        .sheet(item: $activeModal, onDismiss: presentPendingModalIfNeeded) { modal in
            switch modal {
            case .palette(let mode):
                CommandPalette(mode: mode) { command in
                    handlePaletteSelection(command)
                }
            case .keyboardShortcuts:
                KeyboardShortcutsSheet()
            }
        }
        .alert("Folder validation failed", isPresented: repoSelectionErrorPresented, presenting: repoSelectionError) { _ in
            Button("OK", role: .cancel) { repoSelectionError = nil }
        } message: { message in
            Text(message)
        }
        .task(id: backgroundRefreshID) {
            await runBackgroundGitRefresh()
        }
        .onChange(of: store.loadState) { _, newState in
            // Restore the last-selected sidebar tab once the repo finishes
            // loading. We only apply this on the first transition into
            // `.loaded` so subsequent reloads (e.g. force-refresh) don't
            // yank the user back to a tab they intentionally left.
            guard !didApplyInitialTab, newState == .loaded else { return }
            didApplyInitialTab = true
            if let raw = store.repoPreferences.lastSidebarTab,
               let restored = SidebarTab(rawValue: raw) {
                tab = restored
            }
        }
        .onChange(of: tab) { _, newTab in
            store.recordSidebarTab(newTab)
        }
    }

    /// Changes whenever the repo root or load state changes, so the background
    /// refresh task restarts cleanly after onboarding or folder swaps.
    private var backgroundRefreshID: String {
        "\(store.loadState == .loaded ? "loaded" : "idle"):\(RepoConstants.repoRoot.path(percentEncoded: false))"
    }

    /// Polls git every 30s while the content is loaded. Lightweight because
    /// `GitController.refresh` already no-ops when a task is in flight, and
    /// the 30s cadence is well below the fetch/push rate we'd expect.
    private func runBackgroundGitRefresh() async {
        guard store.loadState == .loaded else { return }
        git.refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            if Task.isCancelled { return }
            git.refresh()
        }
    }

    private func handlePaletteSelection(_ command: PaletteCommand) {
        let started = ContinuousClock().now
        switch command {
        case .tab(let selected):
            tab = selected
        case .section(let id, _):
            tab = .home
            store.editingSectionID = id
        case .cta(let id, _):
            tab = .home
            store.editingCTAID = id
        case .project(let fileName, _):
            tab = .projects
            store.selectedProjectFileName = fileName
        case .bodyHit(_, _, let target):
            switch target {
            case .section(let id, _):
                tab = .home
                store.editingSectionID = id
            case .project(let fileName, _):
                tab = .projects
                store.selectedProjectFileName = fileName
            }
        }
        Task { @MainActor in
            await Task.yield()
            store.recordUXMetric("palette.selection.applied", started: started)
        }
    }

    private func requestModal(_ modal: ActiveModal) {
        if activeModal == nil {
            activeModal = modal
            return
        }
        guard activeModal != modal else { return }
        pendingModal = modal
        activeModal = nil
    }

    private func presentPendingModalIfNeeded() {
        guard let pending = pendingModal else { return }
        pendingModal = nil
        Task { @MainActor in
            await Task.yield()
            activeModal = pending
        }
    }

    private func shouldSuppressPaletteOpenRequest(for mode: CommandPalette.Mode) -> Bool {
        if activeModal == .palette(mode) || pendingModal == .palette(mode) {
            return true
        }
        let elapsed = Date().timeIntervalSince(lastPaletteModalRequestAt)
        return lastPaletteModalMode == mode && elapsed < 0.20
    }

    @ViewBuilder
    private var loadedDetail: some View {
        @Bindable var store = store

        ZStack {
            switch tab {
            case .home:
                HomeEditorView()
            case .projects:
                ProjectsRootView()
            case .settings:
                SiteSettingsView()
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                ToastOverlay(toast: $store.toast)
                if let recovery = store.pendingRecovery {
                    DraftRecoveryBanner(
                        recovery: recovery,
                        onRestore: { store.acceptRecovery() },
                        onDiscard: { Task { await store.discardRecovery() } }
                    )
                }
                ExternalChangeBanner(
                    changes: store.externalChanges,
                    onReloadAll: {
                        Task { await store.reloadAllExternalChanges() }
                    },
                    onDismissAll: {
                        for url in store.externalChanges {
                            store.dismissExternalChange(url)
                        }
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                UndoBar(
                    entry: store.pendingUndo,
                    onUndo: { store.performUndo() },
                    onDismiss: { store.dismissUndo() }
                )
                .padding(.horizontal, 18)

                UnsavedChangesBar(
                    isVisible: store.isDirty(for: tab),
                    label: dirtyLabel,
                    onDiscard: { store.discardCurrent(for: tab) },
                    onSave: { Task { await store.saveCurrent(for: tab) } }
                )
            }
        }
        .alert(
            "This file changed on disk",
            isPresented: .constant(store.pendingSaveConflict != nil),
            presenting: store.pendingSaveConflict
        ) { conflict in
            Button("Cancel", role: .cancel) {
                store.cancelConflict()
            }
            Button("Reload from disk", role: .destructive) {
                Task { await store.reloadFromDisk() }
            }
            Button("Keep my edits (overwrite disk)") {
                Task { await store.confirmOverwrite() }
            }
        } message: { conflict in
            Text(
                "\(conflict.displayName) was modified outside Subtext after you opened it. Reload discards your in-memory edits. Overwrite keeps your edits and replaces the file on disk."
            )
        }
    }

    private func pickDifferentFolder(store: CMSStore) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use folder"
        panel.message = "Pick the Astro website repo containing src/content."
        panel.directoryURL = RepoConstants.repoRoot.deletingLastPathComponent()

        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        do {
            try RepoValidator.assertValidRepoSelection(at: chosen)
        } catch {
            repoSelectionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }
        RepoConstants.setRepoRoot(chosen)
        Task { await store.loadAll() }
    }

    private var dirtyLabel: String {
        switch tab {
        case .home:
            return "Unsaved changes in Home"
        case .projects:
            if let file = store.selectedProjectFileName,
               let doc = store.projects.first(where: { $0.fileName == file }) {
                return "Unsaved changes in \(doc.frontmatter.title)"
            }
            return "Unsaved changes in Projects"
        case .settings:
            return "Unsaved changes in Settings"
        }
    }

    private var appAppearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var repoSelectionErrorPresented: Binding<Bool> {
        Binding(
            get: {
                repoSelectionError != nil
            },
            set: { isPresented in
                if !isPresented {
                    repoSelectionError = nil
                }
            }
        )
    }

    private enum ActiveModal: Identifiable, Equatable {
        case palette(CommandPalette.Mode)
        case keyboardShortcuts

        var id: String {
            switch self {
            case .palette(let mode):
                "palette.\(mode.rawValue)"
            case .keyboardShortcuts:
                "keyboardShortcuts"
            }
        }
    }
}

/// Shown while `CMSStore.loadAll()` is running (or before it starts).
private struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Loading content from the website repo")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Full-width error surface with a retry button. Shown whenever `loadAll()`
/// fails (wrong repo path, permissions, parse errors, etc.) so failures are
/// never silent.
private struct LoadFailedView: View {
    let message: String
    var onRetry: () -> Void
    var onPickDifferentFolder: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(.orange)

            Text("Couldn't load the website content")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            Text(RepoConstants.repoRoot.path(percentEncoded: false))
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([RepoConstants.repoRoot])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(action: onPickDifferentFolder) {
                    Label("Pick different folder…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.subtextAccent)
                .keyboardShortcut("r", modifiers: .command)
            }
            .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
