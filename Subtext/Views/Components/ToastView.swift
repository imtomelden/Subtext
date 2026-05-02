import SwiftUI

private enum ToastLayout {
    static let leadingBarWidth: CGFloat = 2
    static let textMaxWidth: CGFloat = 340
}

/// Short-lived confirmation toast shown near the top of the canvas.
struct ToastView: View {
    let message: ToastMessage
    var onDismiss: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Semantic leading edge accent
            Rectangle()
                .fill(edgeColor)
                .frame(width: ToastLayout.leadingBarWidth)
                .clipShape(Capsule())
                .padding(.vertical, 5)
                .padding(.leading, 6)
                .padding(.trailing, 4)

            Image(systemName: iconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(edgeColor)

            Text(message.text)
                .font(SubtextUI.Typography.labelStrong)
                .foregroundStyle(Tokens.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: ToastLayout.textMaxWidth, alignment: .leading)
                .padding(.leading, 6)

            if isHovered {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
                .transition(.opacity)
            }

            Color.clear.frame(width: isHovered ? 6 : 10)
        }
        .padding(.vertical, 6)
        // Hug both axes; `.fixedSize(..., vertical: false)` adopts the overlay’s full height.
        .fixedSize(horizontal: true, vertical: true)
        .background(
            GlassSurface(prominence: .regular, cornerRadius: SubtextUI.Radius.tiny) { Color.clear }
        )
        .onHover { isHovered = $0 }
        .animation(UXMotion.micro, value: isHovered)
        .task {
            let seconds: Double = message.kind == .error ? 4.2 : 2.4
            try? await Task.sleep(for: .seconds(seconds))
            onDismiss()
        }
    }

    private var iconName: String {
        switch message.kind {
        case .success: "checkmark.circle.fill"
        case .error:   "exclamationmark.triangle.fill"
        }
    }

    private var edgeColor: Color {
        switch message.kind {
        case .success: Color.subtextAccent
        case .error:   Color.subtextWarning
        }
    }
}

struct ToastOverlay: View {
    @Binding var toast: ToastMessage?

    var body: some View {
        Group {
            if let t = toast {
                HStack {
                    Spacer(minLength: 0)
                    ToastView(message: t) { toast = nil }
                        .id(t.id)
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
            }
        }
        .animation(UXMotion.micro, value: toast)
        .allowsHitTesting(false)
    }
}
