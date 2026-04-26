import SwiftUI

/// Side-by-side comparison sheet shown before restoring a backup. Reads both
/// the backup and the current live file, runs a line-diff, and lets the user
/// confirm the restore in-place. Used for splash.json, site.json, and the
/// per-project MDX history flows so the experience stays consistent.
struct HistoryDiffSheet: View {
    let title: String
    let backup: BackupService.BackupEntry
    let liveFile: URL
    var onRestore: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var lines: [DiffLine] = []
    @State private var loading = true
    @State private var loadError: String?
    @State private var restoring = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 760, height: 560)
        .task { await loadDiff() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text("Backup from \(absolute(backup.timestamp)) · \(byteString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 14) {
                legendDot(color: Color.red.opacity(0.32), label: "Backup only")
                legendDot(color: Color.green.opacity(0.32), label: "Current only")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.subtextWarning)
                Text("Could not load diff").font(.body.weight(.medium))
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: 0) {
                    side(.backup)
                    Divider()
                    side(.live)
                }
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    @ViewBuilder
    private func side(_ kind: SideKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(kind == .backup ? "Backup" : "Current")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                row(line: line, kind: kind)
            }
        }
        .frame(minWidth: 340, alignment: .leading)
    }

    private func row(line: DiffLine, kind: SideKind) -> some View {
        let cell = cellRender(for: line, kind: kind)
        return HStack(alignment: .top, spacing: 0) {
            Text(cell.text ?? " ")
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 1)
                .background(cell.highlight ?? .clear)
        }
    }

    private func cellRender(for line: DiffLine, kind: SideKind) -> (text: String?, highlight: Color?) {
        switch (line.change, kind) {
        case (.unchanged(let value), _):
            return (value, nil)
        case (.removed(let value), .backup):
            return (value, Color.red.opacity(0.20))
        case (.removed, .live):
            return (nil, nil)
        case (.added(let value), .live):
            return (value, Color.green.opacity(0.20))
        case (.added, .backup):
            return (nil, nil)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if let stats = summaryStats {
                Text(stats)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
            Button("Restore") {
                Task {
                    restoring = true
                    await onRestore()
                    restoring = false
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.subtextAccent)
            .disabled(restoring || loading || loadError != nil)
        }
        .padding(14)
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 10)
            Text(label)
        }
    }

    // MARK: - Loading

    private func loadDiff() async {
        loading = true
        loadError = nil
        do {
            let backupText = try await Task.detached {
                try String(contentsOf: backup.url, encoding: .utf8)
            }.value
            let liveText = (try? await Task.detached {
                try String(contentsOf: liveFile, encoding: .utf8)
            }.value) ?? ""
            let computed = LineDiff.compute(
                old: backupText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init),
                new: liveText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            )
            lines = computed
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    private var byteString: String {
        ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file)
    }

    private func absolute(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var summaryStats: String? {
        let removed = lines.reduce(0) { $0 + ($1.change.isRemoved ? 1 : 0) }
        let added = lines.reduce(0) { $0 + ($1.change.isAdded ? 1 : 0) }
        if removed == 0 && added == 0 { return "No differences" }
        return "\(removed) line\(removed == 1 ? "" : "s") removed · \(added) line\(added == 1 ? "" : "s") added"
    }

    private enum SideKind { case backup, live }
}

// MARK: - Diff model

struct DiffLine: Equatable {
    enum Change: Equatable {
        case unchanged(String)
        case removed(String)
        case added(String)

        var isAdded: Bool { if case .added = self { return true } else { return false } }
        var isRemoved: Bool { if case .removed = self { return true } else { return false } }
    }
    let change: Change
}

/// Minimal line-diff using Swift's built-in `CollectionDifference`. Output is
/// emitted in original-document order with `removed`/`added` markers so the
/// side-by-side renderer can align rows by index.
enum LineDiff {
    static func compute(old: [String], new: [String]) -> [DiffLine] {
        let diff = new.difference(from: old).inferringMoves()
        var oldIdx = 0
        var newIdx = 0
        var result: [DiffLine] = []

        // Build index maps so we can iterate forward in source order.
        var removals: [Int: String] = [:]
        var insertions: [Int: String] = [:]
        for change in diff {
            switch change {
            case .remove(let offset, let element, _):
                removals[offset] = element
            case .insert(let offset, let element, _):
                insertions[offset] = element
            }
        }

        while oldIdx < old.count || newIdx < new.count {
            if let removed = removals[oldIdx], let inserted = insertions[newIdx] {
                if removed == inserted {
                    result.append(DiffLine(change: .unchanged(removed)))
                    oldIdx += 1
                    newIdx += 1
                } else {
                    result.append(DiffLine(change: .removed(removed)))
                    result.append(DiffLine(change: .added(inserted)))
                    oldIdx += 1
                    newIdx += 1
                }
            } else if let removed = removals[oldIdx] {
                result.append(DiffLine(change: .removed(removed)))
                oldIdx += 1
            } else if let inserted = insertions[newIdx] {
                result.append(DiffLine(change: .added(inserted)))
                newIdx += 1
            } else if oldIdx < old.count, newIdx < new.count {
                result.append(DiffLine(change: .unchanged(old[oldIdx])))
                oldIdx += 1
                newIdx += 1
            } else if oldIdx < old.count {
                result.append(DiffLine(change: .removed(old[oldIdx])))
                oldIdx += 1
            } else if newIdx < new.count {
                result.append(DiffLine(change: .added(new[newIdx])))
                newIdx += 1
            } else {
                break
            }
        }
        return result
    }
}
