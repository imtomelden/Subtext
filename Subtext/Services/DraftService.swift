import Foundation

/// Writes unsaved in-memory edits to a hidden `.subtext-drafts/` directory
/// inside the repo root so a crash, power cut, or rogue `killall` doesn't
/// eat an hour of work. On next launch `CMSStore` reads this directory and
/// offers to restore any recovered drafts.
///
/// Drafts are written atomically (temp-file + rename) just like the real
/// saves, so a crashed write never leaves a corrupt file behind.
actor DraftService {
    /// Where the three draft slices live on disk. Root is resolved lazily
    /// against `RepoConstants.repoRoot` so the directory is always inside
    /// the user-selected repo.
    private var root: URL {
        RepoConstants.repoRoot.appending(
            path: ".subtext-drafts",
            directoryHint: .isDirectory
        )
    }

    private var splashURL: URL {
        root.appending(path: "splash.json.draft", directoryHint: .notDirectory)
    }

    private var siteURL: URL {
        root.appending(path: "site.json.draft", directoryHint: .notDirectory)
    }

    private func projectDraftURL(for fileName: String) -> URL {
        root.appending(path: "projects", directoryHint: .isDirectory)
            .appending(path: "\(fileName).draft", directoryHint: .notDirectory)
    }

    // MARK: - Write

    func writeSplashDraft(_ content: SplashContent) throws {
        try writeJSON(content, to: splashURL)
    }

    func writeSiteDraft(_ settings: SiteSettings) throws {
        try writeJSON(settings, to: siteURL)
    }

    func writeProjectDraft(_ document: ProjectDocument) throws {
        let url = projectDraftURL(for: document.fileName)
        let text = MDXSerialiser.serialise(document)
        try atomicWrite(Data(text.utf8), to: url)
    }

    // MARK: - Clear

    func clearSplashDraft() {
        try? FileManager.default.removeItem(at: splashURL)
    }

    func clearSiteDraft() {
        try? FileManager.default.removeItem(at: siteURL)
    }

    func clearProjectDraft(fileName: String) {
        try? FileManager.default.removeItem(at: projectDraftURL(for: fileName))
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Recover

    struct Recovery: Sendable, Equatable {
        var splash: SplashContent?
        var site: SiteSettings?
        var projects: [ProjectDocument] = []

        var isEmpty: Bool {
            splash == nil && site == nil && projects.isEmpty
        }

        var count: Int {
            (splash == nil ? 0 : 1) + (site == nil ? 0 : 1) + projects.count
        }
    }

    /// Scan the drafts directory and return anything we can decode. Silent
    /// failures are fine here — a malformed draft just gets skipped so the
    /// user can proceed with the on-disk baseline.
    func recover() -> Recovery {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path(percentEncoded: false)) else {
            return Recovery()
        }

        var recovery = Recovery()

        if let data = try? Data(contentsOf: splashURL),
           let splash = try? JSONDecoder().decode(SplashContent.self, from: data) {
            recovery.splash = splash
        }

        if let data = try? Data(contentsOf: siteURL),
           let site = try? JSONDecoder().decode(SiteSettings.self, from: data) {
            recovery.site = site
        }

        let projectsDir = root.appending(path: "projects", directoryHint: .isDirectory)
        if let items = try? fm.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in items where url.lastPathComponent.hasSuffix(".draft") {
                let raw = String(url.lastPathComponent.dropLast(".draft".count))
                guard raw.lowercased().hasSuffix(".mdx") else { continue }
                if let text = try? String(contentsOf: url, encoding: .utf8),
                   let doc = try? MDXParser.parse(text, fileName: raw) {
                    recovery.projects.append(doc)
                }
            }
        }

        return recovery
    }

    // MARK: - Helpers

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try atomicWrite(data, to: url)
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let tmp = parent.appending(
            path: "\(url.lastPathComponent).tmp-\(Int(Date().timeIntervalSince1970))",
            directoryHint: .notDirectory
        )
        do {
            try data.write(to: tmp, options: .atomic)
            if fm.fileExists(atPath: url.path(percentEncoded: false)) {
                _ = try fm.replaceItemAt(url, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: url)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw error
        }
    }
}
