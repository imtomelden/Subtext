import Foundation
import Observation

/// LRU store for recently opened projects. Max 6 items, persisted to
/// UserDefaults so recents survive app restarts.
@Observable
final class RecentsStore {
    private static let defaultsKey = "SubtextRecentProjects"
    private static let maxItems = 6

    private(set) var recentFileNames: [String] = []

    init() {
        recentFileNames = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        pruneMissingProjectFiles()
    }

    func record(fileName: String) {
        var list = recentFileNames.filter { $0 != fileName }
        list.insert(fileName, at: 0)
        if list.count > Self.maxItems { list = Array(list.prefix(Self.maxItems)) }
        recentFileNames = list
        UserDefaults.standard.set(list, forKey: Self.defaultsKey)
    }

    func remove(fileName: String) {
        let list = recentFileNames.filter { $0 != fileName }
        guard list.count != recentFileNames.count else { return }
        recentFileNames = list
        UserDefaults.standard.set(list, forKey: Self.defaultsKey)
    }

    /// Drops entries whose project file no longer exists on disk.
    func pruneMissingProjectFiles() {
        let projectsDir = RepoConstants.projectsDirectory
        let fm = FileManager.default
        let filtered = recentFileNames.filter { name in
            let url = projectsDir.appending(path: name, directoryHint: .notDirectory)
            return fm.fileExists(atPath: url.path(percentEncoded: false))
        }
        guard filtered.count != recentFileNames.count else { return }
        recentFileNames = filtered
        UserDefaults.standard.set(filtered, forKey: Self.defaultsKey)
    }
}
