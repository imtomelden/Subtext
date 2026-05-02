import SwiftUI

struct GoalsMetricsBlockEditor: View {
    @Binding var block: GoalsMetricsBlock
    @State private var goalsDrag = DragReorderState(spacing: 10)

    private let itemStackSpacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Title") {
                TextField("Section title", text: $block.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: itemStackSpacing) {
                ReorderableVStack(
                    items: block.items,
                    spacing: itemStackSpacing,
                    dragState: block.items.count > 1 ? goalsDrag : nil,
                    onMove: { block.items.move(fromOffsets: $0, toOffset: $1) }
                ) { item, controls in
                    goalRow(itemID: item.id, controls: controls)
                }

                Button {
                    block.items.append(.init(goal: "", successMeasure: "", baseline: "", target: "", reportingCadence: ""))
                } label: {
                    Label("Add goal", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.subtextAccent)
            }
        }
    }

    @ViewBuilder
    private func goalRow(itemID: GoalsMetricsBlock.Item.ID, controls: AnyView) -> some View {
        if let idx = block.items.firstIndex(where: { $0.id == itemID }) {
            HStack(alignment: .top, spacing: 8) {
                controls

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Goal", text: goal(at: idx))
                        .textFieldStyle(.roundedBorder)
                    TextField("Success measure", text: successMeasure(at: idx))
                        .textFieldStyle(.roundedBorder)
                    TextField("Baseline", text: baseline(at: idx))
                        .textFieldStyle(.roundedBorder)
                    TextField("Target", text: target(at: idx))
                        .textFieldStyle(.roundedBorder)
                    TextField("Reporting cadence", text: cadence(at: idx))
                        .textFieldStyle(.roundedBorder)
                }

                Button(role: .destructive) {
                    block.items.remove(at: idx)
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(SubtextUI.Surface.subtleFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small))
        }
    }

    private func goal(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.goal ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].goal = v } }
        )
    }
    private func successMeasure(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.successMeasure ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].successMeasure = v } }
        )
    }
    private func baseline(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.baseline ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].baseline = v } }
        )
    }
    private func target(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.target ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].target = v } }
        )
    }
    private func cadence(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.reportingCadence ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].reportingCadence = v } }
        )
    }
}
