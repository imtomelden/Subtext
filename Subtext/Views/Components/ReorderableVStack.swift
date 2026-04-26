import SwiftUI

private enum ReorderArrowMetrics {
    static let tapSide: CGFloat = 28
    static let stackSpacing: CGFloat = 2
    static let symbolPointSize: CGFloat = 11
}

/// Vertical stack that renders each row with a pair of up/down arrow buttons
/// for reorder. Click handlers invoke `onMove(IndexSet, Int)` (matching the
/// shape of `List.onMove`), so callers can route directly into existing
/// store mutations like `moveSection(from:to:)`.
///
/// We deliberately avoid `DragGesture` here: the app sets
/// `window.isMovableByWindowBackground = true` together with
/// `.windowStyle(.hiddenTitleBar)`, which means mouse-down on a non-button
/// region starts a window drag before any SwiftUI drag gesture can activate.
/// Clickable buttons sidestep that conflict entirely and come with free
/// keyboard accessibility (Cmd+Up / Cmd+Down on a focused row).
struct ReorderableVStack<Item: Identifiable, Row: View>: View where Item.ID: Hashable {
    private let items: [Item]
    private let spacing: CGFloat
    private let onMove: (IndexSet, Int) -> Void
    private let rowBuilder: (Item, AnyView) -> Row

    init(
        items: [Item],
        spacing: CGFloat = 10,
        onMove: @escaping (IndexSet, Int) -> Void,
        @ViewBuilder row: @escaping (Item, AnyView) -> Row
    ) {
        self.items = items
        self.spacing = spacing
        self.onMove = onMove
        self.rowBuilder = row
    }

    @FocusState private var focusedKey: AnyHashable?

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let key = AnyHashable(item.id)
                rowBuilder(item, reorderControls(at: index))
                    .focusable(items.count > 1)
                    .focused($focusedKey, equals: key)
                    .onKeyPress(.upArrow, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        moveRow(from: index, delta: -1)
                        return .handled
                    }
                    .onKeyPress(.downArrow, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        moveRow(from: index, delta: 1)
                        return .handled
                    }
            }
        }
        .animation(.snappy(duration: 0.22), value: items.map(\.id))
    }

    private func reorderControls(at index: Int) -> AnyView {
        let isFirst = index == 0
        let isLast = index == items.count - 1
        return AnyView(
            VStack(spacing: ReorderArrowMetrics.stackSpacing) {
                Button {
                    moveRow(from: index, delta: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: ReorderArrowMetrics.symbolPointSize, weight: .semibold))
                        .frame(width: ReorderArrowMetrics.tapSide, height: ReorderArrowMetrics.tapSide)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(isFirst)
                .help("Move up")
                .accessibilityLabel("Move up")

                Button {
                    moveRow(from: index, delta: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: ReorderArrowMetrics.symbolPointSize, weight: .semibold))
                        .frame(width: ReorderArrowMetrics.tapSide, height: ReorderArrowMetrics.tapSide)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(isLast)
                .help("Move down")
                .accessibilityLabel("Move down")
            }
            .foregroundStyle(.secondary)
            .frame(minWidth: ReorderArrowMetrics.tapSide)
        )
    }

    private func moveRow(from index: Int, delta: Int) {
        let target = index + delta
        guard items.indices.contains(index), items.indices.contains(target) else { return }

        // Capture the moved item's ID *before* the mutation so we can
        // re-focus it afterwards (the post-mutation array has the item at
        // `target`, but the closure here still sees the old array).
        let movedID = AnyHashable(items[index].id)
        let toOffset = delta > 0 ? target + 1 : target

        withAnimation(.snappy(duration: 0.22)) {
            onMove(IndexSet(integer: index), toOffset)
        }

        AccessibilityNotification.Announcement(
            "Moved to position \(target + 1) of \(items.count)"
        ).post()

        DispatchQueue.main.async {
            focusedKey = movedID
        }
    }
}
