import SwiftUI

// MARK: - State

/// Observable state that drives physics-based drag-to-reorder on a list.
///
/// Each row measures its height and registers it here. As the user drags,
/// `peerOffset(for:in:)` tells every non-dragged row how far to shift so
/// items visually open a gap at the current drop target.
///
/// Usage:
///   1. Create one instance per list (e.g. `@State private var drag = DragReorderState(spacing: 8)`).
///   2. Pass it to `ReorderableVStack(dragState: drag, ...)`.
///   3. `ReorderableVStack` handles the rest — height registration, handle gesture, offsets.
@Observable
final class DragReorderState {
    var activeID: AnyHashable? = nil
    var translation: CGFloat = 0
    let spacing: CGFloat

    private(set) var heightByID: [AnyHashable: CGFloat] = [:]

    var isDragging: Bool { activeID != nil }

    func isDragging<ID: Hashable>(id: ID) -> Bool {
        activeID == AnyHashable(id)
    }

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func registerHeight(_ height: CGFloat, for id: AnyHashable) {
        heightByID[id] = height
    }

    func begin(id: AnyHashable) {
        activeID = id
        translation = 0
    }

    func update(_ dy: CGFloat) {
        translation = dy
    }

    /// Commit the drag: call `onMove` with the final target index, then reset.
    func commit<Item: Identifiable>(
        items: [Item],
        onMove: (IndexSet, Int) -> Void
    ) where Item.ID: Hashable {
        guard let activeID,
              let src = items.firstIndex(where: { AnyHashable($0.id) == activeID })
        else { reset(); return }
        let dst = targetIndex(src: src, items: items)
        reset()
        guard dst != src else { return }
        onMove(IndexSet(integer: src), dst > src ? dst + 1 : dst)
    }

    func cancel() { reset() }

    // MARK: - Offset computation

    /// Vertical offset for the actively dragged row (gesture follow).
    func draggedOffset(for id: AnyHashable) -> CGFloat {
        activeID == id ? translation : 0
    }

    /// Index ``0 ... items.count`` where a drop insertion line is drawn **above**
    /// that row (or after the last row when equal to `items.count`). `nil` when
    /// idle or the drag would not reorder.
    func insertionSlotAbove<Item: Identifiable>(in items: [Item]) -> Int?
        where Item.ID: Hashable
    {
        guard let activeID,
              let src = items.firstIndex(where: { AnyHashable($0.id) == activeID })
        else { return nil }
        let dst = targetIndex(src: src, items: items)
        guard dst != src else { return nil }
        if dst > src {
            let slot = dst + 1
            return min(slot, items.count)
        }
        return dst
    }

    /// Vertical displacement for a non-dragged peer (slides to open gap).
    func peerOffset<Item: Identifiable>(for item: Item, in items: [Item]) -> CGFloat
        where Item.ID: Hashable
    {
        let id = AnyHashable(item.id)
        guard let activeID, id != activeID,
              let src = items.firstIndex(where: { AnyHashable($0.id) == activeID }),
              let myIdx = items.firstIndex(where: { $0.id == item.id })
        else { return 0 }

        let dst = targetIndex(src: src, items: items)
        guard dst != src else { return 0 }
        let step = (heightByID[activeID] ?? 60) + spacing

        if src < dst {
            return (myIdx > src && myIdx <= dst) ? -step : 0
        } else {
            return (myIdx >= dst && myIdx < src) ? step : 0
        }
    }

    // MARK: - Private

    private func targetIndex<Item: Identifiable>(src: Int, items: [Item]) -> Int
        where Item.ID: Hashable
    {
        guard activeID != nil else { return src }
        let abs = Swift.abs(translation)
        let goingDown = translation > 0
        var acc: CGFloat = 0

        if goingDown {
            for i in (src + 1)..<items.count {
                let h = (heightByID[AnyHashable(items[i].id)] ?? 60) + spacing
                acc += h
                if abs < acc - h / 2 { return i - 1 }
                if i == items.count - 1 { return i }
            }
        } else {
            for i in stride(from: src - 1, through: 0, by: -1) {
                let h = (heightByID[AnyHashable(items[i].id)] ?? 60) + spacing
                acc += h
                if abs < acc - h / 2 { return i + 1 }
                if i == 0 { return i }
            }
        }
        return src
    }

    private func reset() {
        withAnimation(Motion.spring) {
            activeID = nil
            translation = 0
        }
    }
}

// MARK: - Window drag exclusion

/// An invisible NSView whose sole job is returning `false` from
/// `mouseDownCanMoveWindow`. AppKit checks this property on the hit-tested
/// view *before* any SwiftUI gesture sees the event, so SwiftUI-level fixes
/// (highPriorityGesture, minimumDistance: 0) cannot win the race.
/// Placing this view as the background of a drag handle tells AppKit: "this
/// area is interactive — don't treat it as a window-drag region."
private struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> BlockerView { BlockerView() }
    func updateNSView(_ nsView: BlockerView, context: Context) {}

    class BlockerView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
    }
}

// MARK: - Drag Handle

/// A grab-handle that wires into `DragReorderState` via a `DragGesture`.
///
/// Uses `WindowDragBlocker` as its background so AppKit never routes
/// mouse-down events from this area to the window-drag mechanism, regardless
/// of `isMovableByWindowBackground`.
struct DragHandle<Item: Identifiable>: View where Item.ID: Hashable {
    let item: Item
    let items: [Item]
    let state: DragReorderState
    let onMove: (IndexSet, Int) -> Void

    @State private var isHovered = false

    private var isActive: Bool { state.activeID == AnyHashable(item.id) }

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isHovered || isActive ? Color.subtextAccent : Color(nsColor: .tertiaryLabelColor))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .background(WindowDragBlocker())
            .onHover { isHovered = $0 }
            .animation(Motion.micro, value: isHovered)
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { value in
                        let id = AnyHashable(item.id)
                        if state.activeID == nil {
                            withAnimation(Motion.snappy) { state.begin(id: id) }
                        }
                        withAnimation(Motion.drag) {
                            state.update(value.translation.height)
                        }
                    }
                    .onEnded { _ in
                        state.commit(items: items, onMove: onMove)
                    }
            )
            .accessibilityLabel("Drag handle")
            .accessibilityHint("Drag up or down to reorder")
    }
}
