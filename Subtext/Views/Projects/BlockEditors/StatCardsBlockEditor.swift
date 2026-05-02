import SwiftUI

struct KeyStatsBlockEditor: View {
    @Binding var block: KeyStatsBlock
    @State private var statsDrag = DragReorderState(spacing: 10)
    @State private var expandedStatID: KeyStatsBlock.Item.ID? = nil

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
                    dragState: block.items.count > 1 ? statsDrag : nil,
                    onMove: { block.items.move(fromOffsets: $0, toOffset: $1) }
                ) { item, controls in
                    statRow(itemID: item.id, controls: controls)
                }

                Button {
                    withAnimation(Motion.short) { expandedStatID = nil }
                    let newItem = KeyStatsBlock.Item(
                        label: "", valuePrefix: nil, value: "", unit: nil,
                        context: nil, lastUpdated: ISO8601Date.today()
                    )
                    block.items.append(newItem)
                    withAnimation(Motion.short) { expandedStatID = newItem.id }
                } label: {
                    Label("Add stat", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.subtextAccent)
            }
        }
    }

    // MARK: - Stat row dispatcher

    @ViewBuilder
    private func statRow(itemID: KeyStatsBlock.Item.ID, controls: AnyView) -> some View {
        if let idx = block.items.firstIndex(where: { $0.id == itemID }) {
            let isExpanded = expandedStatID == itemID
            VStack(spacing: 0) {
                if isExpanded {
                    expandedStatRow(idx: idx, itemID: itemID, controls: controls)
                        .transition(.opacity)
                } else {
                    collapsedStatRow(idx: idx, itemID: itemID, controls: controls)
                        .transition(.opacity)
                }
            }
            .animation(Motion.short, value: isExpanded)
        }
    }

    // MARK: - Collapsed row

    @ViewBuilder
    private func collapsedStatRow(idx: Int, itemID: KeyStatsBlock.Item.ID, controls: AnyView) -> some View {
        HStack(alignment: .center, spacing: 8) {
            controls

            VStack(alignment: .leading, spacing: 2) {
                let item = block.items[safe: idx]
                Text(item?.label.isEmpty == false ? item!.label : "Untitled stat")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Text.primary)
                    .lineLimit(1)
                let parts = [item?.valuePrefix, item?.value, item?.unit]
                    .compactMap { s -> String? in guard let s, !s.isEmpty else { return nil }; return s }
                let summary = parts.joined(separator: " ")
                if !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(Motion.short) { expandedStatID = itemID }
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Edit stat")

            Button(role: .destructive) {
                block.items.remove(at: idx)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SubtextUI.Surface.subtleFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation(Motion.short) { expandedStatID = itemID }
        }
        .contextMenu {
            Button("Edit") {
                withAnimation(Motion.short) {
                    expandedStatID = (expandedStatID == itemID) ? nil : itemID
                }
            }
            Button("Duplicate") {
                var copy = block.items[idx]
                copy.id = UUID()
                block.items.insert(copy, at: idx + 1)
            }
            Divider()
            Button("Delete", role: .destructive) {
                if expandedStatID == itemID { expandedStatID = nil }
                block.items.remove(at: idx)
            }
        }
    }

    // MARK: - Expanded row

    @ViewBuilder
    private func expandedStatRow(idx: Int, itemID: KeyStatsBlock.Item.ID, controls: AnyView) -> some View {
        HStack(alignment: .top, spacing: 8) {
            controls

            VStack(alignment: .leading, spacing: 8) {
                TextField("Label", text: label(at: idx))
                    .textFieldStyle(.roundedBorder)
                TextField("Value prefix (optional)", text: valuePrefix(at: idx))
                    .textFieldStyle(.roundedBorder)
                TextField("Value", text: value(at: idx))
                    .textFieldStyle(.roundedBorder)
                TextField("Unit (optional)", text: unit(at: idx))
                    .textFieldStyle(.roundedBorder)
                TextField("Context note (optional)", text: context(at: idx))
                    .textFieldStyle(.roundedBorder)
                TextField("Last updated (YYYY-MM-DD)", text: lastUpdated(at: idx))
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                withAnimation(Motion.short) { expandedStatID = nil }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.subtextAccent)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Collapse")

            Button(role: .destructive) {
                if expandedStatID == itemID { expandedStatID = nil }
                block.items.remove(at: idx)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(SubtextUI.Surface.subtleFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small))
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") {
                withAnimation(Motion.short) {
                    expandedStatID = (expandedStatID == itemID) ? nil : itemID
                }
            }
            Button("Duplicate") {
                var copy = block.items[idx]
                copy.id = UUID()
                block.items.insert(copy, at: idx + 1)
            }
            Divider()
            Button("Delete", role: .destructive) {
                if expandedStatID == itemID { expandedStatID = nil }
                block.items.remove(at: idx)
            }
        }
    }

    // MARK: - Bindings

    private func label(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.label ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].label = v } }
        )
    }
    private func value(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.value ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].value = v } }
        )
    }
    private func valuePrefix(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.valuePrefix ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].valuePrefix = v.isEmpty ? nil : v } }
        )
    }
    private func unit(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.unit ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].unit = v.isEmpty ? nil : v } }
        )
    }
    private func context(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.context ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].context = v.isEmpty ? nil : v } }
        )
    }
    private func lastUpdated(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.lastUpdated ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].lastUpdated = v } }
        )
    }
}

extension Array {
    subscript(safe idx: Int) -> Element? {
        indices.contains(idx) ? self[idx] : nil
    }
}
