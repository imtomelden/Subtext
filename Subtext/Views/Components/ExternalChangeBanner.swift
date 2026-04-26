import SwiftUI

/// Non-blocking top banner that appears when `CMSStore`'s watcher notices
/// that a content file was modified by something other than Subtext (`git
/// pull`, external editor, another Subtext window). Gives the user a
/// one-click "Reload" escape so their next save doesn't silently stomp on
/// the out-of-band change.
///
/// Hidden when there are no pending external changes.
struct ExternalChangeBanner: View {
    let changes: Set<URL>
    var onReloadAll: () -> Void
    var onDismissAll: () -> Void

    var body: some View {
        if changes.isEmpty {
            EmptyView()
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(Color.subtextWarning)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.callout.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 12)

                Button(action: onReloadAll) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.subtextAccent)

                Button(action: onDismissAll) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Keep the in-memory version")
                .accessibilityLabel("Dismiss external change notice")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.subtextWarning.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.subtextWarning.opacity(0.35), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var headline: String {
        changes.count == 1
            ? "\(changes.first!.lastPathComponent) changed outside Subtext"
            : "\(changes.count) files changed outside Subtext"
    }

    private var detail: String {
        let names = changes
            .map { $0.lastPathComponent }
            .sorted()
            .prefix(3)
            .joined(separator: ", ")
        let tail = changes.count > 3 ? ", …" : ""
        return "Reload to pick up the on-disk version — or keep editing to overwrite them."
            + (changes.count > 1 ? " (\(names)\(tail))" : "")
    }
}
