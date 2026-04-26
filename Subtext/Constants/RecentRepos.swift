import Foundation

/// Persists a short list of security-scoped bookmark payloads so people can
/// jump between a few Astro repos without re-picking every time.
enum RecentRepos {
    private static let udKey = "SubtextRecentRepoBookmarks"
    private static let maxCount = 5

    /// Call after the primary bookmark has been written to UserDefaults.
    static func recordCurrentPrimaryBookmark() {
        guard let data = UserDefaults.standard.data(forKey: RepoConstants.bookmarkKey),
              !data.isEmpty
        else { return }

        var list = (UserDefaults.standard.array(forKey: udKey) as? [Data]) ?? []
        list.removeAll { $0 == data }
        list.insert(data, at: 0)
        if list.count > maxCount {
            list = Array(list.prefix(maxCount))
        }
        UserDefaults.standard.set(list, forKey: udKey)
    }

    /// Bookmarks that resolve to a folder URL, for Settings UI.
    static func resolvedEntries() -> [(bookmark: Data, url: URL, label: String)] {
        let list = (UserDefaults.standard.array(forKey: udKey) as? [Data]) ?? []
        var out: [(Data, URL, String)] = []
        for data in list {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { continue }
            let normalised = URL(
                fileURLWithPath: url.path(percentEncoded: false),
                isDirectory: true
            )
            out.append((data, normalised, normalised.lastPathComponent))
        }
        return out
    }
}
