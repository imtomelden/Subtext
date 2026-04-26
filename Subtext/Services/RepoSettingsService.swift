import Foundation

/// Per-repo, on-disk settings live under `.subtext/preferences.json` at the
/// repo root. This is for state that should travel with the repo on a
/// machine swap (last-open project, last-selected sidebar tab, expanded
/// disclosure groups), as opposed to global app preferences (theme,
/// content density) that stay in `UserDefaults`.
///
/// The service is an actor because both reads and writes touch disk and
/// can race with other autosave-style writes.
actor RepoSettingsService {
    private static let directoryName = ".subtext"
    private static let fileName = "preferences.json"

    /// Reads `repoRoot/.subtext/preferences.json`, returning `default` if
    /// the file is missing or unreadable. Never throws — settings are
    /// best-effort; a corrupted file shouldn't block the repo from loading.
    func read() async -> RepoPreferences {
        let url = Self.preferencesURL()
        guard
            let data = try? Data(contentsOf: url),
            let prefs = try? JSONDecoder().decode(RepoPreferences.self, from: data)
        else {
            return .empty
        }
        return prefs
    }

    /// Writes `prefs` to disk, ensuring the `.subtext` directory exists.
    /// Errors are swallowed — losing the next-launch project pointer is a
    /// minor inconvenience, not a data-loss event.
    func write(_ prefs: RepoPreferences) async {
        let directory = Self.directoryURL()
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path(percentEncoded: false)) {
            do {
                try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(prefs) else { return }
        try? data.write(to: Self.preferencesURL(), options: [.atomic])
    }

    /// Convenience used by the store: read, mutate, and write back in one
    /// hop without the caller wrangling the actor twice.
    func update(_ transform: @Sendable (inout RepoPreferences) -> Void) async {
        var current = await read()
        transform(&current)
        await write(current)
    }

    // MARK: - Paths

    private static func directoryURL() -> URL {
        RepoConstants.repoRoot.appending(path: directoryName, directoryHint: .isDirectory)
    }

    private static func preferencesURL() -> URL {
        directoryURL().appending(path: fileName, directoryHint: .notDirectory)
    }
}

/// Per-repo editor preferences serialised to `.subtext/preferences.json`.
///
/// Add fields cautiously and keep them all optional / defaulted — a missing
/// field should always decode cleanly so older `.subtext/preferences.json`
/// files keep working after an app upgrade.
struct RepoPreferences: Codable, Equatable, Sendable {
    /// The MDX file name (e.g. `case-study.mdx`) the user had open last.
    /// Restored on next launch so re-opening the repo lands them back in
    /// the same project without re-navigating.
    var lastOpenProjectFileName: String?

    /// Sidebar tab the user finished on (`home`, `projects`, `site`).
    /// Stored as the raw string of `SidebarTab` so the type can change
    /// without breaking on-disk compatibility.
    var lastSidebarTab: String?

    /// Has the user dismissed the draft-recovery prompt for this repo
    /// since their last completed save? Lets us avoid re-prompting on
    /// every launch when the user keeps choosing "discard".
    var dismissedDraftRecovery: Bool?

    /// Open/closed state of the long disclosure groups in the project
    /// editor — keyed by section identifier (e.g. `"caseStudy"`,
    /// `"hero"`). `true` = open. Lets editors keep their preferred view.
    var expandedDisclosures: [String: Bool]?

    static let empty = RepoPreferences()
}
