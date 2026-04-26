import Foundation

/// Poll-based watcher that notices when content files have been modified by
/// anything other than Subtext itself (git pull, Cursor/Vim edit, another
/// instance of Subtext, etc.) and hands a debounced set of changed URLs
/// back on the main actor.
///
/// **Why polling, not `DispatchSourceFileSystemObject` / FSEvents?** The
/// tracked set is O(dozens) — `splash.json`, `site.json`, plus one `.mdx`
/// per project — and a 2-second tick is imperceptible to the user but
/// trivial to reason about, handles file renames cleanly, and avoids the
/// CoreFoundation callback dance that FSEvents demands. Upgrade later only
/// if the content tree grows by an order of magnitude.
///
/// The watcher also takes a "we just wrote this" acknowledgement from
/// `CMSStore.save*` so our own writes never surface as external changes.
@MainActor
final class ContentWatcher {
    private let interval: Duration
    private var task: Task<Void, Never>?
    private var stamps: [URL: Date] = [:]
    private let onChange: (Set<URL>) -> Void

    init(
        interval: Duration = .seconds(2),
        onChange: @escaping (Set<URL>) -> Void
    ) {
        self.interval = interval
        self.onChange = onChange
    }

    /// Begin polling. Replaces any previous watch.
    func start(paths: [URL]) {
        stop()
        stamps = Dictionary(
            uniqueKeysWithValues: paths.map { ($0, Self.modDate(of: $0)) }
        )
        task = Task { [weak self, interval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Replace the watched set in-place (e.g. a project was created or
    /// deleted). Missing URLs are timestamped as `distantPast` so they
    /// immediately register as "new" if they later appear.
    func replaceWatched(_ paths: [URL]) {
        var next: [URL: Date] = [:]
        for path in paths {
            next[path] = stamps[path] ?? Self.modDate(of: path)
        }
        stamps = next
    }

    /// Record that Subtext just wrote this file, so the next tick treats
    /// the new mtime as the baseline rather than an external change.
    func acknowledgeOwnWrite(_ url: URL) {
        stamps[url] = Self.modDate(of: url)
    }

    /// Current known mtime for a file — used by `CMSStore.save*` to do
    /// last-moment conflict detection against the on-disk mtime.
    func knownMtime(for url: URL) -> Date? {
        stamps[url]
    }

    // MARK: - Private

    private func tick() {
        var changed: Set<URL> = []
        for (url, previous) in stamps {
            let current = Self.modDate(of: url)
            if current != previous {
                stamps[url] = current
                changed.insert(url)
            }
        }
        if !changed.isEmpty {
            onChange(changed)
        }
    }

    static func modDate(of url: URL) -> Date {
        let attrs = try? FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false)
        )
        return (attrs?[.modificationDate] as? Date) ?? .distantPast
    }
}
