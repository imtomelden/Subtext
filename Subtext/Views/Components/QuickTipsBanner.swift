import SwiftUI

/// One-time dismissible hints for palette, preview, and focus mode.
struct QuickTipsBanner: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.subtextAccent)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Quick tips")
                    .font(.callout.weight(.semibold))
                Text("Go to anything — ⌘K · Find in content — ⌘F · Live preview — ⌥⌘P · Focus mode (hide sidebar) — ⌃⌘F")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss tips")
        }
        .padding(12)
        .background(
            GlassSurface(prominence: .interactive, cornerRadius: 12) { Color.clear }
        )
        .padding(.horizontal, 18)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
