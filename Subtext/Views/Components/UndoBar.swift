import SwiftUI

/// Floating banner shown after reversible destructive actions (section /
/// CTA / block delete). Offers an explicit Undo and auto-dismisses so it
/// never blocks the canvas.
struct UndoBar: View {
    let entry: CMSStore.UndoEntry?
    var onUndo: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        Group {
            if let entry {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.title3)
                        .foregroundStyle(Color.subtextAccent)

                    Text(entry.label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button("Undo", action: onUndo)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.subtextAccent)
                        .keyboardShortcut("z", modifiers: .command)

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    GlassSurface(prominence: .thick, cornerRadius: 12) { Color.clear }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(entry.id)
            }
        }
        .animation(UXMotion.short, value: entry?.id)
    }
}
