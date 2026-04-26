import SwiftUI

/// Short-lived confirmation toast shown near the top of the canvas.
struct ToastView: View {
    let message: ToastMessage
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(message.kind == .success ? Color.subtextAccent : .orange)
            Text(message.text)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            GlassSurface(prominence: .thick, cornerRadius: 10) { Color.clear }
        )
        .task {
            let seconds: Double = message.kind == .error ? 4.2 : 2.4
            try? await Task.sleep(for: .seconds(seconds))
            onDismiss()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
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
        .animation(.spring(response: 0.35, dampingFraction: 0.84), value: toast)
        .allowsHitTesting(false)
    }
}
