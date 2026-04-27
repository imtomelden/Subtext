import SwiftUI

struct CtaBlockEditor: View {
    @Binding var block: CTABlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Heading") {
                TextField("Heading", text: $block.title)
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow("Description") {
                TextField("Optional description", text: Binding(
                    get: { block.description ?? "" },
                    set: { block.description = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }

            FieldRow("Links") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(block.links.indices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Label", text: label(at: idx))
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                TextField("href", text: href(at: idx))
                                    .textFieldStyle(.roundedBorder)
                                Button(role: .destructive) {
                                    block.links.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(SubtextUI.Surface.subtleFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small))
                    }

                    Button {
                        block.links.append(.init(label: "", href: ""))
                    } label: {
                        Label("Add link", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.subtextAccent)
                }
            }
        }
    }

    private func label(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.links[safe: idx]?.label ?? "" },
            set: { v in if idx < block.links.count { block.links[idx].label = v } }
        )
    }
    private func href(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.links[safe: idx]?.href ?? "" },
            set: { v in if idx < block.links.count { block.links[idx].href = v } }
        )
    }
}
