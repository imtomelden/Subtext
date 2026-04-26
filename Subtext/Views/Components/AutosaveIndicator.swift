import SwiftUI

/// Lightweight toolbar pill that surfaces the autosave safety net.
///
/// Three states:
/// - `dirty == true && lastPersisted != nil`: "Draft saved · Xs ago"
/// - `dirty == true && lastPersisted == nil`: "Editing — autosave shortly"
/// - `dirty == false`: hidden entirely (callers conditionally render)
///
/// Drafts are written by `CMSStore.persistDraftsIfDirty` on a 5s loop; this
/// indicator re-renders every second via a timer so the relative time stays
/// honest without forcing a full store update.
struct AutosaveIndicator: View {
    let isDirty: Bool
    let lastPersistedAt: Date?

    @State private var now: Date = .now

    private static let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if isDirty {
                HStack(spacing: 5) {
                    Image(systemName: lastPersistedAt == nil ? "ellipsis.circle" : "tray.and.arrow.down")
                        .imageScale(.small)
                    Text(label)
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.subtextSubtleFill)
                )
                .help(lastPersistedAt == nil
                      ? "A local autosave will run within five seconds."
                      : "Drafts live under `.subtext-drafts/` and are restored if the app crashes.")
                .onReceive(Self.timer) { now = $0 }
                .accessibilityLabel(label)
            } else {
                EmptyView()
            }
        }
    }

    private var label: String {
        guard let last = lastPersistedAt else { return "Editing…" }
        let elapsed = max(0, now.timeIntervalSince(last))
        return "Draft saved · \(formatted(seconds: elapsed))"
    }

    private func formatted(seconds: TimeInterval) -> String {
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(Int(seconds))s ago" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}
