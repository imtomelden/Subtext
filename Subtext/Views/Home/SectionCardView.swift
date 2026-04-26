import SwiftUI

struct SectionCardView: View {
    let section: SplashSection
    var reorderControls: AnyView? = nil
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var confirmDelete = false

    var body: some View {
        DraggableCard(reorderControls: reorderControls) {
            HStack(spacing: 8) {
                visualBadge
                if section.isHero {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 13))
                }
            }
        } content: {
            HStack(alignment: .top, spacing: 10) {
                if let mediaPath = sectionMediaPath {
                    AssetMediaThumbnail(src: mediaPath, size: 44, cornerRadius: 7)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.heading.isEmpty ? "Untitled section" : section.heading)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if let subtitle = section.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(section.previewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        } trailing: {
            HStack(spacing: 6) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Edit section")
                .accessibilityLabel("Edit section")

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Delete section")
                .accessibilityLabel("Delete section")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .alert("Delete this section?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(section.heading)” will be removed. You can undo right after.")
        }
    }

    private var sectionMediaPath: String? {
        switch section.visual {
        case .photo(let visual):
            return visual.src
        default:
            return nil
        }
    }

    @ViewBuilder
    private var visualBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: section.sectionSystemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(section.sectionLabel)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.subtextAccent)
        .background(
            Capsule().fill(Color.subtextAccent.opacity(0.18))
        )
    }
}

struct CTACardView: View {
    let cta: SplashCTA
    var reorderControls: AnyView? = nil
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var confirmDelete = false

    var body: some View {
        DraggableCard(reorderControls: reorderControls) {
            Image(systemName: "hand.point.up.braille.fill")
                .foregroundStyle(Color.subtextAccent)
                .frame(width: 22)
        } content: {
            VStack(alignment: .leading, spacing: 2) {
                Text(cta.name.isEmpty ? "Untitled CTA" : cta.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(cta.heading.isEmpty ? "No heading" : cta.heading)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(cta.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } trailing: {
            HStack(spacing: 6) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Edit CTA")
                .accessibilityLabel("Edit CTA")

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Delete CTA")
                .accessibilityLabel("Delete CTA")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .alert("Delete this CTA?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}
