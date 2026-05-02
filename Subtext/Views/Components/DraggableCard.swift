import SwiftUI

/// Shell for a card row. Manages:
///
///   * an optional reorder controls slot (supplied by `ReorderableVStack`)
///   * `.glassEffect(.interactive)` surface
///   * consistent padding + min height
///
/// The reorder controls are a pair of up/down chevron buttons — not a drag
/// handle — because macOS window-drag-by-background conflicts with SwiftUI
/// `DragGesture`s in this app's hidden-titlebar window style.
struct DraggableCard<Content: View, Leading: View, Trailing: View>: View {
    private let reorderControls: AnyView?

    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let content: () -> Content
    @ViewBuilder let trailing: () -> Trailing

    init(
        reorderControls: AnyView? = nil,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.reorderControls = reorderControls
        self.leading = leading
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        Surface(.surface, cornerRadius: 14) {
            HStack(spacing: 12) {
                if let reorderControls {
                    reorderControls
                }

                leading()

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)

                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(minHeight: 40)
        }
    }
}
