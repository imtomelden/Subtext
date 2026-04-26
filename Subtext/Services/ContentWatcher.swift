import CoreServices
import Foundation

/// Event-driven watcher that notices when content files have been modified
/// by anything other than Subtext itself (git pull, Cursor/Vim edit, another
/// instance of Subtext, etc.) and hands a debounced set of changed URLs back
/// on the main actor.
///
/// **Implementation.** Backed by `FSEventStream` rooted at the parent
/// directories of every watched file, with a small mtime check inside the
/// callback to filter out events for siblings we don't care about. This
/// scales to repos with hundreds of MDX projects without polling, and drops
/// our IO-tick to ~zero when the user isn't editing.
///
/// We still keep an in-memory `stamps: [URL: Date]` map so:
///  - `acknowledgeOwnWrite` can update the baseline without surfacing our
///    own write as an external change, and
///  - `knownMtime(for:)` lets `CMSStore.save*` perform last-moment conflict
///    detection when we re-write a file.
@MainActor
final class ContentWatcher {
    private let onChange: (Set<URL>) -> Void
    private let coalesceLatency: CFTimeInterval
    private var stream: FSEventStreamRef?
    private var stamps: [URL: Date] = [:]
    private var watchedDirectories: Set<URL> = []

    init(
        coalesceLatency: CFTimeInterval = 0.25,
        onChange: @escaping (Set<URL>) -> Void
    ) {
        self.coalesceLatency = coalesceLatency
        self.onChange = onChange
    }

    isolated deinit {
        // FSEvents must be torn down before the surrounding object goes
        // away. `isolated deinit` keeps us on the main actor so we can
        // touch the stream pointer without crossing actors.
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    /// Begin watching the supplied content paths. Replaces any previous
    /// stream so this is safe to call repeatedly (e.g. when a project is
    /// added/removed).
    func start(paths: [URL]) {
        stop()
        stamps = Dictionary(
            uniqueKeysWithValues: paths.map { ($0, Self.modDate(of: $0)) }
        )
        rebuildStream()
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        watchedDirectories.removeAll()
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
        // Rebuild the stream only if the set of watched directories shifted —
        // most "I added a project" updates land within an already-watched
        // directory and don't need a new stream.
        let nextDirs = Self.parentDirectories(of: paths)
        if nextDirs != watchedDirectories {
            rebuildStream()
        }
    }

    /// Record that Subtext just wrote this file, so the next event treats
    /// the new mtime as the baseline rather than an external change.
    func acknowledgeOwnWrite(_ url: URL) {
        stamps[url] = Self.modDate(of: url)
    }

    /// Current known mtime for a file — used by `CMSStore.save*` to do
    /// last-moment conflict detection against the on-disk mtime.
    func knownMtime(for url: URL) -> Date? {
        stamps[url]
    }

    // MARK: - FSEvents wiring

    private func rebuildStream() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }

        let directories = Self.parentDirectories(of: Array(stamps.keys))
        watchedDirectories = directories
        guard !directories.isEmpty else { return }

        let paths = directories.map { $0.path(percentEncoded: false) } as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
            | kFSEventStreamCreateFlagUseCFTypes
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<ContentWatcher>.fromOpaque(info).takeUnretainedValue()
            // `kFSEventStreamCreateFlagUseCFTypes` gives us a CFArray of CFStrings.
            guard let cfPaths = unsafeBitCast(eventPaths, to: CFArray.self) as? [String] else {
                return
            }
            let snapshot = Array(cfPaths.prefix(numEvents))
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    watcher.handleEventPaths(snapshot)
                }
            }
        }

        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            coalesceLatency,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(newStream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(newStream)
        stream = newStream
    }

    private func handleEventPaths(_ paths: [String]) {
        var changed: Set<URL> = []
        // FSEvents reports per-file paths thanks to `kFSEventStreamCreateFlagFileEvents`.
        // For each, see if it matches one of our tracked URLs and whether the
        // mtime really changed (avoids spurious notifications from atime,
        // metadata churn, etc.).
        for raw in paths {
            let url = URL(fileURLWithPath: raw)
            guard stamps.keys.contains(url) else { continue }
            let current = Self.modDate(of: url)
            if current != stamps[url] {
                stamps[url] = current
                changed.insert(url)
            }
        }
        // Some editors write via temp+rename, which surfaces under the
        // *directory* path rather than the file path. As a fallback, walk
        // every watched URL whose parent directory was reported.
        let reportedDirs: Set<String> = Set(paths.map {
            URL(fileURLWithPath: $0).deletingLastPathComponent().path(percentEncoded: false)
        })
        for (url, previous) in stamps {
            let parent = url.deletingLastPathComponent().path(percentEncoded: false)
            guard reportedDirs.contains(parent) else { continue }
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

    // MARK: - Helpers

    private static func parentDirectories(of urls: [URL]) -> Set<URL> {
        var dirs: Set<URL> = []
        for url in urls {
            dirs.insert(url.deletingLastPathComponent())
        }
        return dirs
    }

    static func modDate(of url: URL) -> Date {
        let attrs = try? FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false)
        )
        return (attrs?[.modificationDate] as? Date) ?? .distantPast
    }
}
