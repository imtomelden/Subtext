import SwiftUI

/// Sticky bottom bar that appears whenever the current tab has unsaved edits.
struct UnsavedChangesBar: View {
    let isVisible: Bool
    let label: String
    var onDiscard: () -> Void
    var onSave: () -> Void

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.subtextAccent)
                        .frame(width: 8, height: 8)

                    Text(label)
                        .font(SubtextUI.Typography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Button("Discard", action: onDiscard)
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                    Button("Save", action: onSave)
                        .keyboardShortcut("s", modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.subtextAccent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    GlassSurface(prominence: .thick, cornerRadius: SubtextUI.Glass.panelCornerRadius) { Color.clear }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(UXMotion.short, value: isVisible)
    }
}
