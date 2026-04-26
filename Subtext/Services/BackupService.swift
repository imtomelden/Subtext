import Foundation

/// Manages `.subtext-backups/*.bak` files.
///
/// Convention on disk:
///   `{filename-with-ext}.{unix-timestamp}.bak`
///
/// The service:
///   * creates backups when requested by the store (session-close or
///     destructive actions),
///   * creates a backup before every restore,
///   * lists backups per live file,
///   * restores a chosen backup back into place,
///   * prunes old backups to `RepoConstants.backupRetentionPerFile`.
actor BackupService {
    enum BackupError: LocalizedError {
        case backupDirectoryUnavailable(String)
        case backupReadFailed(URL, String)
        case restoreFailed(URL, String)

        var errorDescription: String? {
            switch self {
            case .backupDirectoryUnavailable(let reason):
                "Backup folder unavailable: \(reason)"
            case .backupReadFailed(let url, let reason):
                "Could not read backup \(url.lastPathComponent): \(reason)"
            case .restoreFailed(let url, let reason):
                "Restore failed for \(url.lastPathComponent): \(reason)"
            }
        }
    }

    struct BackupEntry: Identifiable, Equatable, Sendable {
        var id: URL { url }
        var url: URL
        var timestamp: Date
        var size: Int64
        var sourceFileName: String
    }

    // MARK: - Create

    /// Copies the current file on disk into `.subtext-backups/` with a
    /// timestamp suffix, then prunes beyond the retention window.
    /// No-op if the source file does not yet exist.
    func createBackup(for liveFile: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: liveFile.path(percentEncoded: false)) else { return }

        try ensureBackupsDirectory()

        let timestamp = Int(Date().timeIntervalSince1970)
        let dest = RepoConstants.backupsDirectory.appending(
            path: "\(liveFile.lastPathComponent).\(timestamp).bak",
            directoryHint: .notDirectory
        )

        if fm.fileExists(atPath: dest.path(percentEncoded: false)) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: liveFile, to: dest)

        try pruneBackups(for: liveFile.lastPathComponent)
    }

    // MARK: - List

    func listBackups(for fileName: String) throws -> [BackupEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: RepoConstants.backupsDirectory.path(percentEncoded: false)) else {
            return []
        }
        let urls = try fm.contentsOfDirectory(
            at: RepoConstants.backupsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        let prefix = fileName + "."
        let matches = urls.filter {
            $0.pathExtension.lowercased() == "bak"
                && $0.lastPathComponent.hasPrefix(prefix)
        }

        let entries = try matches.compactMap { url -> BackupEntry? in
            guard let ts = parseTimestamp(from: url, prefix: prefix) else { return nil }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let size = Int64(values.fileSize ?? 0)
            return BackupEntry(
                url: url,
                timestamp: Date(timeIntervalSince1970: TimeInterval(ts)),
                size: size,
                sourceFileName: fileName
            )
        }

        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Restore

    /// Copies `backup` back onto `target`. Before the copy, a fresh backup of
    /// the current state is written so the restore itself is reversible.
    func restore(backup: URL, to target: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backup.path(percentEncoded: false)) else {
            throw BackupError.restoreFailed(target, "Backup no longer exists.")
        }

        try createBackup(for: target)

        do {
            let data = try Data(contentsOf: backup)
            let parent = target.deletingLastPathComponent()
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            let tmp = parent.appending(
                path: "\(target.lastPathComponent).restore-\(Int(Date().timeIntervalSince1970))",
                directoryHint: .notDirectory
            )
            try data.write(to: tmp, options: .atomic)
            if fm.fileExists(atPath: target.path(percentEncoded: false)) {
                _ = try fm.replaceItemAt(target, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: target)
            }
        } catch {
            throw BackupError.restoreFailed(target, "\(error)")
        }
    }

    // MARK: - Pruning

    func pruneBackups(for fileName: String) throws {
        let entries = try listBackups(for: fileName)
        let retention = RepoConstants.backupRetentionPerFile
        guard entries.count > retention else { return }

        let fm = FileManager.default
        for entry in entries.dropFirst(retention) {
            try? fm.removeItem(at: entry.url)
        }
    }

    // MARK: - Internals

    private func ensureBackupsDirectory() throws {
        let fm = FileManager.default
        let dir = RepoConstants.backupsDirectory
        if !fm.fileExists(atPath: dir.path(percentEncoded: false)) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                throw BackupError.backupDirectoryUnavailable("\(error)")
            }
        }
    }

    private func parseTimestamp(from url: URL, prefix: String) -> Int? {
        let name = url.lastPathComponent
        guard name.hasPrefix(prefix), name.hasSuffix(".bak") else { return nil }
        let middle = name.dropFirst(prefix.count).dropLast(".bak".count)
        return Int(middle)
    }
}
