import SwiftUI

struct HistoryRow: View {
    let entry: BackupService.BackupEntry
    var onRestore: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(relativeString)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(sizeString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.4), in: Capsule())

            Button("Restore", action: onRestore)
                .buttonStyle(.bordered)
                .tint(Color.subtextAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var relativeString: String {
        Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: Date())
    }

    private var absoluteString: String {
        Self.absoluteFormatter.string(from: entry.timestamp)
    }

    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
