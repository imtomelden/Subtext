import SwiftUI

/// Short-lived confirmation toast shown near the top of the canvas.
struct ToastView: View {
    let message: ToastMessage
    var onDismiss: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Semantic 3pt leading edge bar
            Rectangle()
                .fill(edgeColor)
                .frame(width: 3)
                .clipShape(Capsule())
                .padding(.vertical, 8)
                .padding(.leading, 8)
                .padding(.trailing, 6)

            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(edgeColor)

            Text(message.text)
                .font(.callout.weight(.medium))
                .foregroundStyle(Tokens.Text.primary)
                .padding(.leading, 8)

            Spacer(minLength: 8)

            if isHovered {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .padding(.trailing, isHovered ? 0 : 14)
        .background(
            GlassSurface(prominence: .thick, cornerRadius: 10) { Color.clear }
        )
        .onHover { isHovered = $0 }
        .animation(UXMotion.micro, value: isHovered)
        .task {
            let seconds: Double = message.kind == .error ? 4.2 : 2.4
            try? await Task.sleep(for: .seconds(seconds))
            onDismiss()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
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
        VStack {
            if let t = toast {
                ToastView(message: t) { toast = nil }
                    .padding(.top, 20)
                    .id(t.id)
            }
            Spacer()
        }
        .animation(UXMotion.micro, value: toast)
        .allowsHitTesting(false)
    }
}
