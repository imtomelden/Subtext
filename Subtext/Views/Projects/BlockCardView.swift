import SwiftUI

struct BlockCardView: View {
    let block: ProjectBlock
    var reorderControls: AnyView? = nil
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        DraggableCard(reorderControls: reorderControls) {
            blockPill
        } content: {
            HStack(alignment: .top, spacing: SubtextUI.Spacing.small + 2) {
                if let mediaPath = previewMediaPath {
                    AssetMediaThumbnail(src: mediaPath, size: 40, cornerRadius: SubtextUI.Radius.tiny)
                }
                VStack(alignment: .leading, spacing: SubtextUI.Spacing.xSmall - 2) {
                    Text(block.kind.displayName)
                        .font(SubtextUI.Typography.bodyStrong)
                    Text(block.inlinePreview)
                        .font(SubtextUI.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } trailing: {
            HStack(spacing: SubtextUI.Spacing.small - 2) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .controlSize(.small)

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .controlSize(.small)
            }
        }
        .contentShape(Rectangle())
        .hoverLift(scale: 1.003, shadowRadius: 4)
        .onTapGesture(count: 2, perform: onEdit)
        .alert(blockDeleteAlertTitle, isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This block will be removed. You can undo right after.")
        }
    }

    private var blockPill: some View {
        let tint = block.kind.tintRGB
        let color = Color(red: tint.r, green: tint.g, blue: tint.b)
        return HStack(spacing: 4) {
            Image(systemName: block.kind.systemImage)
                .font(.caption2.weight(.semibold))
            Text(block.kind.displayName.uppercased())
                .font(SubtextUI.Typography.microLabel)
                .tracking(0.4)
        }
        .foregroundStyle(color)
        .padding(.horizontal, SubtextUI.Spacing.small)
        .padding(.vertical, SubtextUI.Spacing.xSmall)
        .background(Capsule().fill(color.opacity(0.16)))
    }

    private var blockDeleteAlertTitle: String {
        let label = block.inlinePreview.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = label.isEmpty ? block.kind.displayName : String(label.prefix(80))
        return "Delete \"\(named)\"?"
    }

    private var previewMediaPath: String? {
        switch block {
        case .mediaGallery(let media):
            return media.items.first?.src
        case .headerImage(let h):
            return h.src
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
