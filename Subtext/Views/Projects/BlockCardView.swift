import SwiftUI

struct BlockCardView: View {
    let block: ProjectBlock
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        DraggableCard {
            blockPill
        } content: {
            HStack(alignment: .top, spacing: 10) {
                if let mediaPath = previewMediaPath {
                    AssetMediaThumbnail(src: mediaPath, size: 40, cornerRadius: 7)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.kind.displayName)
                        .font(.body.weight(.semibold))
                    Text(block.inlinePreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } trailing: {
            HStack(spacing: 6) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .alert("Delete this block?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var blockPill: some View {
        let tint = block.kind.tintRGB
        let color = Color(red: tint.r, green: tint.g, blue: tint.b)
        return HStack(spacing: 4) {
            Image(systemName: block.kind.systemImage)
                .font(.caption2.weight(.semibold))
            Text(block.kind.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.4)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.18)))
    }

    private var previewMediaPath: String? {
        switch block {
        case .mediaGallery(let media):
            return media.items.first?.src
        case .videoShowcase(let video):
            switch video.source {
            case .youtube, .vimeo:
                return nil
            case .file(let src, let poster, _, _, _):
                return poster ?? src
            }
        default:
            return nil
        }
    }
}
