import SwiftUI

// MARK: - Dismiss action

/// Closure-based dismiss action injected into modals presented via
/// `View.subtextModal(item:style:onDismiss:content:)`.
///
/// Content views read this from the environment instead of SwiftUI's built-in
/// `DismissAction` (which is only injected by `.sheet` / navigation, not by
/// custom overlays).
///
///     @Environment(\.dismissModal) private var dismiss
///     Button("Done") { dismiss() }
/// Always invoked on the main thread via SwiftUI's view body.
/// `@unchecked Sendable` is safe here because the struct is a pure UI
/// primitive; every call site is inside a `@MainActor` SwiftUI view.
struct DismissModalAction: @unchecked Sendable {
    fileprivate let action: () -> Void

    func callAsFunction() {
        action()
    }
}

private struct DismissModalKey: EnvironmentKey {
    static let defaultValue = DismissModalAction(action: {})
}

extension EnvironmentValues {
    /// Dismiss action for modals presented via `subtextModal`.
    var dismissModal: DismissModalAction {
        get { self[DismissModalKey.self] }
        set { self[DismissModalKey.self] = newValue }
    }
}

// MARK: - View modifier

extension View {
    /// Presents a custom modal overlay driven by `item` — a drop-in
    /// replacement for `.sheet(item:)` with Subtext's motion vocabulary.
    ///
    /// The overlay consists of:
    /// 1. A dimmed backdrop that dismisses on tap.
    /// 2. Modal content with a `Motion.bouncy` scale-in entrance transition.
    ///
    /// The content view receives `\.dismissModal` so it can dismiss itself.
    /// For `ModalStyle.glassCard`, the host wraps content in `GlassSurface`.
    /// For `ModalStyle.command`, content provides its own chrome.
    ///
    /// - Parameters:
    ///   - item: Binding to the presented item; setting it to `nil` dismisses.
    ///   - style: Visual treatment — `.command` or `.glassCard`.
    ///   - onDismiss: Called after the modal is dismissed.
    ///   - content: View builder receiving the unwrapped item.
    func subtextModal<Item: Identifiable, ModalContent: View>(
        item: Binding<Item?>,
        style: @escaping (Item) -> ModalStyle,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> ModalContent
    ) -> some View {
        modifier(
            SubtextModalModifier(
                item: item,
                style: style,
                onDismiss: onDismiss,
                content: content
            )
        )
    }
}

// MARK: - Modifier implementation

private struct SubtextModalModifier<Item: Identifiable, ModalContent: View>: ViewModifier {
    @Binding var item: Item?
    let style: (Item) -> ModalStyle
    let onDismiss: (() -> Void)?
    @ViewBuilder let content: (Item) -> ModalContent

    func body(content outer: Content) -> some View {
        ZStack {
            outer

            // Backdrop + modal content rendered as a single unit so that
            // the `if let` branch drives one shared presence animation.
            if let presented = item {
                backdrop
                    .zIndex(100)

                modalContent(for: presented)
                    .environment(\.dismissModal, DismissModalAction { dismiss() })
                    .zIndex(101)
            }
        }
        // Single bouncy animation drives both appearance and disappearance.
        .animation(Motion.bouncy, value: item?.id.hashValue)
    }

    // MARK: - Sub-views

    private var backdrop: some View {
        Color.black.opacity(0.38)
            .ignoresSafeArea()
            .transition(.opacity)
            .onTapGesture { dismiss() }
    }

    @ViewBuilder
    private func modalContent(for presented: Item) -> some View {
        switch style(presented) {
        case .command:
            content(presented)
                .transition(.subtextScale)

        case .glassCard(let width, let height):
            GlassSurface(prominence: .thick, cornerRadius: SubtextUI.Glass.shellCornerRadius) {
                content(presented)
                    .frame(width: width, height: height)
            }
            .transition(.subtextScale)
        }
    }

    // MARK: - Helpers

    private func dismiss() {
        item = nil
        onDismiss?()
    }
}
