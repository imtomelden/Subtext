import Foundation

/// All paths the app needs are derived from a single repo root. The default
/// is set for this machine, but users can override it via Settings. Reads
/// must work from any isolation (actors read it to launch the dev server),
/// so the root itself lives in a `nonisolated(unsafe)` cache that is only
/// mutated from the main actor.
///
/// The chosen root is persisted as a **security-scoped bookmark** (with a
/// legacy path fallback). The bookmark is what lets Subtext read and write
/// inside `~/Documents` without the macOS TCC folder-access prompt firing
/// on every launch: when the user picks the folder through `NSOpenPanel`,
/// Powerbox grants explicit consent tied to that bookmark, and we never
/// touch the filesystem at init time until that bookmark exists.
enum RepoConstants {
    /// The default repo location — only shown as the suggested starting
    /// directory in the picker. Never accessed programmatically without a
    /// user-granted bookmark.
    static let defaultRepoRoot: URL = URL(
        fileURLWithPath: "/Users/tomblagden/Documents/Projects/Website",
        isDirectory: true
    )

    /// Legacy (pre-bookmark) UserDefaults key — still read on launch so an
    /// existing install doesn't lose its root.
    static let defaultsKey: String = "SubtextRepoRootPath"

    /// UserDefaults key for the security-scoped bookmark data.
    static let bookmarkKey: String = "SubtextRepoRootBookmark"

    private struct ResolvedRoot {
        var url: URL
        var hasUserSelection: Bool
    }

    /// Backing storage. Resolved lazily once, then mutated through the
    /// main-actor-gated setters below.
    nonisolated(unsafe) private static var _state: ResolvedRoot = {
        let resolved = Self.resolveStoredRoot()
        if resolved.hasUserSelection {
            // Required when the URL came from a security-scoped bookmark;
            // harmless no-op on a plain file URL. Intentionally never
            // `stop` — the root is used for the lifetime of the process.
            _ = resolved.url.startAccessingSecurityScopedResource()
        }
        return resolved
    }()

    static var repoRoot: URL { _state.url }

    /// `true` when the user has explicitly picked the repo through
    /// `NSOpenPanel` (i.e. we hold a security-scoped bookmark). When this
    /// is `false` we must NOT read anything under `repoRoot` — doing so
    /// would trigger a TCC prompt for `~/Documents`.
    static var hasUserSelectedRoot: Bool { _state.hasUserSelection }

    @MainActor
    static func setRepoRoot(_ url: URL) {
        if _state.hasUserSelection {
            _state.url.stopAccessingSecurityScopedResource()
        }

        let normalised = URL(
            fileURLWithPath: url.path(percentEncoded: false),
            isDirectory: true
        )

        // Persist as a security-scoped bookmark. The bookmark encodes the
        // user's Powerbox grant so subsequent launches can re-access the
        // folder without another TCC prompt.
        if let data = try? normalised.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
        UserDefaults.standard.set(
            normalised.path(percentEncoded: false),
            forKey: defaultsKey
        )

        _ = normalised.startAccessingSecurityScopedResource()
        _state = ResolvedRoot(url: normalised, hasUserSelection: true)
        RecentRepos.recordCurrentPrimaryBookmark()
    }

    @MainActor
    static func resetToDefaultRepoRoot() {
        if _state.hasUserSelection {
            _state.url.stopAccessingSecurityScopedResource()
        }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        _state = ResolvedRoot(url: defaultRepoRoot, hasUserSelection: false)
    }

    static var isUsingDefaultRepoRoot: Bool {
        repoRoot.path(percentEncoded: false) == defaultRepoRoot.path(percentEncoded: false)
    }

    /// `src/content` directory.
    static var contentDirectory: URL {
        repoRoot.appending(path: "src", directoryHint: .isDirectory)
                .appending(path: "content", directoryHint: .isDirectory)
    }

    /// `src/content/splash.json`.
    static var splashFile: URL {
        contentDirectory.appending(path: "splash.json", directoryHint: .notDirectory)
    }

    /// `src/content/site.json`.
    static var siteFile: URL {
        contentDirectory.appending(path: "site.json", directoryHint: .notDirectory)
    }

    /// `src/content/projects` (holds the `.mdx` case studies).
    static var projectsDirectory: URL {
        contentDirectory.appending(path: "projects", directoryHint: .isDirectory)
    }

    /// `.subtext-backups` at the repo root.
    static var backupsDirectory: URL {
        repoRoot.appending(path: ".subtext-backups", directoryHint: .isDirectory)
    }

    /// `public/` — resolves relative image references used in content.
    static var publicDirectory: URL {
        repoRoot.appending(path: "public", directoryHint: .isDirectory)
    }

    /// Retention for per-file backups.
    static let backupRetentionPerFile: Int = 20

    /// Minimum window size.
    static let minimumWindowSize: CGSize = CGSize(width: 1100, height: 720)

    /// Fixed sidebar width.
    /// Sidebar column — slightly wider ideal so git status and titles truncate less.
    static let sidebarWidth: CGFloat = 244

    /// Detail panel width.
    static let detailPanelWidth: CGFloat = 600

    /// Astro's default dev-server port — matches `npm run dev` in Website/.
    static let devServerURL: URL = URL(string: "http://localhost:4321")!

    // MARK: - Private

    /// Resolve the stored root in preference order: bookmark → legacy path
    /// → compiled-in default. **Never stats the filesystem for paths we do
    /// not already have consent for** — statting `~/Documents` can trigger
    /// TCC, which is exactly what we're trying to avoid. We trust the
    /// bookmark's resolve step as the sole liveness check; stale/invalid
    /// bookmarks fall through to onboarding.
    private static func resolveStoredRoot() -> ResolvedRoot {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: bookmarkKey) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale,
                   let fresh = try? url.bookmarkData(
                       options: [.withSecurityScope],
                       includingResourceValuesForKeys: nil,
                       relativeTo: nil
                   ) {
                    defaults.set(fresh, forKey: bookmarkKey)
                }
                defaults.set(url.path(percentEncoded: false), forKey: defaultsKey)
                return ResolvedRoot(url: url, hasUserSelection: true)
            }
        }

        if let stored = defaults.string(forKey: defaultsKey), !stored.isEmpty {
            // Legacy install: we have a path but no bookmark. Surface it
            // so Settings can display the previous choice, but treat it as
            // "no user selection" so onboarding still runs and creates a
            // proper bookmark on first launch.
            return ResolvedRoot(
                url: URL(fileURLWithPath: stored, isDirectory: true),
                hasUserSelection: false
            )
        }

        return ResolvedRoot(url: defaultRepoRoot, hasUserSelection: false)
    }
}
