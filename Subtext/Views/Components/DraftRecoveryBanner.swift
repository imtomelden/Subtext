import SwiftUI

/// Startup banner surfaced when `.subtext-drafts/` held unsaved edits
/// from a previous session. Gives the user a one-click "recover into
/// memory" or "discard and move on" choice before they start editing.
struct DraftRecoveryBanner: View {
    let recovery: DraftService.Recovery
    var onRestore: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "tray.full.fill")
                .foregroundStyle(Color.subtextAccent)
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

            Button(action: onRestore) {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.subtextAccent)

            Button(action: onDiscard) {
                Label("Discard", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.subtextAccent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.subtextAccent.opacity(0.35), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var headline: String {
        "Recovered \(recovery.count) unsaved draft\(recovery.count == 1 ? "" : "s") from the last session"
    }

    private var detail: String {
        var parts: [String] = []
        if recovery.splash != nil { parts.append("splash.json") }
        if recovery.site != nil { parts.append("site.json") }
        if !recovery.projects.isEmpty {
            parts.append("\(recovery.projects.count) project\(recovery.projects.count == 1 ? "" : "s")")
        }
        return "Restore to reapply your edits as unsaved changes — or discard to keep only what's on disk. (\(parts.joined(separator: ", ")))"
    }
}
