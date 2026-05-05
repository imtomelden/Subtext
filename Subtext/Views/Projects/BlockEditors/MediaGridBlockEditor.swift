import SwiftUI

struct MediaGalleryBlockEditor: View {
    @Binding var block: MediaGalleryBlock
    @State private var mediaDrag = DragReorderState(spacing: 12)

    private let itemStackSpacing: CGFloat = 12

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
                    dragState: block.items.count > 1 ? mediaDrag : nil,
                    onMove: { block.items.move(fromOffsets: $0, toOffset: $1) }
                ) { item, controls in
                    mediaRow(itemID: item.id, controls: controls)
                }

                Button {
                    block.items.append(.init(src: "", alt: "", caption: nil, credit: nil, date: nil, location: nil))
                } label: {
                    Label("Add media", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.subtextAccent)
            }
        }
    }

    @ViewBuilder
    private func mediaRow(itemID: MediaGalleryBlock.Item.ID, controls: AnyView) -> some View {
        if let idx = block.items.firstIndex(where: { $0.id == itemID }) {
            HStack(alignment: .top, spacing: 8) {
                controls

                VStack(alignment: .leading, spacing: 8) {
                    AssetPathField(path: src(at: idx), placeholder: "/images/…")

                    TextField("Alt text", text: alt(at: idx))
                        .textFieldStyle(.roundedBorder)
                    TextField("Caption (optional)", text: caption(at: idx))
                        .textFieldStyle(.roundedBorder)
                    TextField("Source/Credit (optional)", text: credit(at: idx))
                        .textFieldStyle(.roundedBorder)
                    DateField(value: date(at: idx))
                    TextField("Location (optional)", text: location(at: idx))
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

    private func src(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.src ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].src = v } }
        )
    }
    private func alt(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.alt ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].alt = v } }
        )
    }
    private func caption(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.caption ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].caption = v.isEmpty ? nil : v } }
        )
    }
    private func credit(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.credit ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].credit = v.isEmpty ? nil : v } }
        )
    }
    private func date(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.date ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].date = v.isEmpty ? nil : v } }
        )
    }
    private func location(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.location ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].location = v.isEmpty ? nil : v } }
        )
    }
}
