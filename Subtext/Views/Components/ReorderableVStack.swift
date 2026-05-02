import SwiftUI

private enum ReorderArrowMetrics {
    static let tapSide: CGFloat = 28
    static let stackSpacing: CGFloat = 2
    static let symbolPointSize: CGFloat = 11
}

/// Vertical stack with reorder support — either drag handles (physics) or
/// chevron-button arrows (a11y/keyboard). Both modes keep `⌘↑` / `⌘↓` working.
///
/// **Drag mode** — pass a `DragReorderState` initialised with the same `spacing`
/// as this stack. Each row gets a `DragHandle`; peers animate with `Motion.bouncy`
/// as the drop target updates; the dragged row lifts with scale + shadow.
///
/// **Arrow mode** — omit `dragState`. Rows get up/down chevron buttons and the
/// original focus-chain keyboard shortcuts.
struct ReorderableVStack<Item: Identifiable, Row: View>: View where Item.ID: Hashable {
    private let items: [Item]
    private let spacing: CGFloat
    private let dragState: DragReorderState?
    private let onMove: (IndexSet, Int) -> Void
    private let rowBuilder: (Item, AnyView) -> Row

    init(
        items: [Item],
        spacing: CGFloat = 10,
        dragState: DragReorderState? = nil,
        onMove: @escaping (IndexSet, Int) -> Void,
        @ViewBuilder row: @escaping (Item, AnyView) -> Row
    ) {
        self.items = items
        self.spacing = spacing
        self.dragState = dragState
        self.onMove = onMove
        self.rowBuilder = row
    }

    @FocusState private var focusedKey: AnyHashable?

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let key = AnyHashable(item.id)
                let isActive = dragState?.activeID == key
                let insertionSlot = dragState?.insertionSlotAbove(in: items)

                if let slot = insertionSlot, slot == index {
                    dropInsertionLine
                }

                rowBuilder(item, controls(at: index, item: item))
                    // Height registration for drag physics
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                        dragState?.registerHeight(h, for: key)
                    }
                    // Drag or peer offset
                    .offset(y: rowOffset(for: item, isActive: isActive))
                    // Lift effect while dragging this row
                    .scaleEffect(isActive ? 1.02 : 1, anchor: .center)
                    .opacity(isActive ? 0.85 : 1)
                    .shadow(
                        color: isActive ? .black.opacity(0.22) : .clear,
                        radius: isActive ? 16 : 0,
                        y: isActive ? 7 : 0
                    )
                    .zIndex(isActive ? 10 : 0)
                    // Physics: fast spring on drag follow, bouncy for peers
                    .animation(
                        isActive ? Motion.drag : Motion.bouncy,
                        value: rowOffset(for: item, isActive: isActive)
                    )
                    .animation(Motion.snappy, value: isActive)
                    // Keyboard reorder — focusEffectDisabled suppresses the
                    // blue outline while keeping ⌘↑↓ keyboard nav working.
                    .focusable(items.count > 1)
                    .focusEffectDisabled()
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

            if let slot = dragState?.insertionSlotAbove(in: items), slot == items.count {
                dropInsertionLine
            }
        }
        // Animate insertions/deletions only when not mid-drag
        .animation(dragState?.isDragging == true ? nil : UXMotion.short, value: items.map(\.id))
    }

    private var dropInsertionLine: some View {
        Rectangle()
            .fill(Color.subtextAccent)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // MARK: - Offset

    private func rowOffset(for item: Item, isActive: Bool) -> CGFloat {
        guard let dragState else { return 0 }
        return isActive
            ? dragState.draggedOffset(for: AnyHashable(item.id))
            : dragState.peerOffset(for: item, in: items)
    }

    // MARK: - Controls

    private func controls(at index: Int, item: Item) -> AnyView {
        if let dragState {
            // Drag mode: handle + arrows together so keyboard users still have buttons.
            return AnyView(
                HStack(spacing: 0) {
                    DragHandle(item: item, items: items, state: dragState, onMove: onMove)
                    chevronArrows(at: index)
                }
            )
        }
        return chevronControls(at: index)
    }

    /// Up/down chevron buttons without outer wrapper — used inside drag mode controls.
    private func chevronArrows(at index: Int) -> some View {
        let isFirst = index == 0
        let isLast = index == items.count - 1
        return VStack(spacing: ReorderArrowMetrics.stackSpacing) {
            Button { moveRow(from: index, delta: -1) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: ReorderArrowMetrics.symbolPointSize, weight: .semibold))
                    .frame(width: ReorderArrowMetrics.tapSide, height: ReorderArrowMetrics.tapSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(isFirst)
            .help("Move up (⌘↑)")
            .accessibilityLabel("Move up")

            Button { moveRow(from: index, delta: 1) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: ReorderArrowMetrics.symbolPointSize, weight: .semibold))
                    .frame(width: ReorderArrowMetrics.tapSide, height: ReorderArrowMetrics.tapSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(isLast)
            .help("Move down (⌘↓)")
            .accessibilityLabel("Move down")
        }
        .foregroundStyle(.secondary)
    }

    private func chevronControls(at index: Int) -> AnyView {
        AnyView(
            chevronArrows(at: index)
                .frame(minWidth: ReorderArrowMetrics.tapSide)
        )
    }

    // MARK: - Move

    private func moveRow(from index: Int, delta: Int) {
        let target = index + delta
        guard items.indices.contains(index), items.indices.contains(target) else { return }
        let movedID = AnyHashable(items[index].id)
        let toOffset = delta > 0 ? target + 1 : target
        withAnimation(UXMotion.short) {
            onMove(IndexSet(integer: index), toOffset)
        }
        AccessibilityNotification.Announcement(
            "Moved to position \(target + 1) of \(items.count)"
        ).post()
        DispatchQueue.main.async { focusedKey = movedID }
    }
}
