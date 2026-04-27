import SwiftUI

struct KeyStatsBlockEditor: View {
    @Binding var block: KeyStatsBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Title") {
                TextField("Section title", text: $block.title)
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(block.items.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Label", text: label(at: idx))
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

                Button {
                    block.items.append(.init(
                        label: "",
                        value: "",
                        unit: nil,
                        context: nil,
                        lastUpdated: ISO8601Date.today()
                    ))
                } label: {
                    Label("Add stat", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.subtextAccent)
            }
        }
    }

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
