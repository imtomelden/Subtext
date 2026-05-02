import SwiftUI

struct CtaBlockEditor: View {
    @Binding var block: CTABlock
    @State private var linksDrag = DragReorderState(spacing: 10)

    private let itemStackSpacing: CGFloat = 10

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
                VStack(alignment: .leading, spacing: itemStackSpacing) {
                    ReorderableVStack(
                        items: block.links,
                        spacing: itemStackSpacing,
                        dragState: block.links.count > 1 ? linksDrag : nil,
                        onMove: { block.links.move(fromOffsets: $0, toOffset: $1) }
                    ) { link, controls in
                        linkRow(linkID: link.id, controls: controls)
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

    @ViewBuilder
    private func linkRow(linkID: CTABlock.Link.ID, controls: AnyView) -> some View {
        if let idx = block.links.firstIndex(where: { $0.id == linkID }) {
            HStack(alignment: .top, spacing: 8) {
                controls

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Label", text: label(at: idx))
                        .textFieldStyle(.roundedBorder)
                    TextField("href", text: href(at: idx))
                        .textFieldStyle(.roundedBorder)
                }

                Button(role: .destructive) {
                    block.links.remove(at: idx)
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
