import SwiftUI

/// Expandable card for a `SplashSection` on the home canvas.
///
/// - **Collapsed**: compact badge + heading + preview + action buttons.
/// - **Editing**: same compact header, then a `Divider` + `SectionInlineEditor`
///   below — no side panel required.
///
/// The accent-colour ring and `Motion.spring` expansion replace the old
/// `SlidingPanel` pattern.
struct SectionBlockHostView: View {
    @Binding var section: SplashSection
    let isEditing: Bool
    var reorderControls: AnyView?
    var onToggleEdit: () -> Void
    var onDelete: () -> Void

    @State private var confirmDelete = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            compactRow

            if isEditing {
                SectionInlineEditor(section: $section)
                    .padding(16)
                    .background(
                        Tokens.Fill.metaCard
                            .overlay(alignment: .top) {
                                Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
                            }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .animation(Motion.spring, value: isEditing)
        .onHover { isHovered = $0 }
        .alert(
            section.heading.isEmpty ? "Delete \"Untitled section\"?" : "Delete \"\(section.heading)\"?",
            isPresented: $confirmDelete
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This section will be removed. You can undo right after.")
        }
    }

    // MARK: - Compact row

    @ViewBuilder
    private var compactRow: some View {
        HStack(spacing: 10) {
            // Drag handle
            if let reorderControls {
                reorderControls
            } else {
                VStack(spacing: 2.5) {
                    Rectangle().fill(Tokens.Text.secondary.opacity(0.20)).frame(width: 12, height: 1)
                    Rectangle().fill(Tokens.Text.secondary.opacity(0.20)).frame(width: 12, height: 1)
                }
                .frame(width: 18)
            }

            // Up/down arrows
            VStack(spacing: 2) {
                Text("▲").font(.system(size: 9)).foregroundStyle(Tokens.Text.tertiary)
                Text("▼").font(.system(size: 9)).foregroundStyle(Tokens.Text.tertiary)
            }

            // Type pill
            sectionTypePill

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(section.heading.isEmpty ? "Untitled section" : section.heading)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Tokens.Text.primary)
                    .lineLimit(1)
                    .tracking(-0.13)
                Text(section.previewText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Thumbnail
            if let mediaPath = sectionMediaPath {
                AssetMediaThumbnail(src: mediaPath, size: 36, cornerRadius: 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Tokens.Fill.tag))
            }

            // Edit / overflow
            HStack(spacing: 2) {
                Button(action: onToggleEdit) {
                    Text(isEditing ? "▲" : "✎")
                        .font(.system(size: 10))
                        .foregroundStyle(isEditing ? Color.subtextAccent : Tokens.Text.tertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(isEditing ? "Collapse" : "Edit section")

                Menu {
                    Button("Edit", action: onToggleEdit)
                    Divider()
                    Button("Delete", role: .destructive) { confirmDelete = true }
                } label: {
                    Text("⋮")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.vertical, 10)
        .background(isEditing ? Color.subtextAccent.opacity(0.08) : Color.clear)
        .animation(Motion.short, value: isEditing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
        }
    }

    private var sectionMediaPath: String? {
        if case .photo(let p) = section.visual { return p.src }
        return nil
    }

    @ViewBuilder
    private var sectionTypePill: some View {
        let name = section.sectionLabel.uppercased()
        Text(name)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.subtextAccent)
            .tracking(0.9)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.subtextAccent.opacity(0.18)))
    }
}

// MARK: -

/// Expandable card for a `SplashCTA` on the home canvas.
struct CTABlockHostView: View {
    @Binding var cta: SplashCTA
    let isEditing: Bool
    var reorderControls: AnyView?
    var onToggleEdit: () -> Void
    var onDelete: () -> Void

    @State private var confirmDelete = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            compactRow

            if isEditing {
                CTAInlineEditor(cta: $cta)
                    .padding(16)
                    .background(
                        Tokens.Fill.metaCard
                            .overlay(alignment: .top) {
                                Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
                            }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .animation(Motion.spring, value: isEditing)
        .onHover { isHovered = $0 }
        .alert(ctaDeleteAlertTitle, isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This CTA will be removed. You can undo right after.")
        }
    }

    @ViewBuilder
    private var compactRow: some View {
        HStack(spacing: 10) {
            if let reorderControls {
                reorderControls
            } else {
                VStack(spacing: 2.5) {
                    Rectangle().fill(Tokens.Text.secondary.opacity(0.20)).frame(width: 12, height: 1)
                    Rectangle().fill(Tokens.Text.secondary.opacity(0.20)).frame(width: 12, height: 1)
                }
                .frame(width: 18)
            }

            // Type pill
            Text("CTA")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.subtextAccent)
                .tracking(0.9)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.subtextAccent.opacity(0.18)))

            Text(cta.heading.isEmpty ? (cta.name.isEmpty ? "Untitled CTA" : cta.name) : cta.heading)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Tokens.Text.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button(action: onToggleEdit) {
                    Text(isEditing ? "▲" : "✎")
                        .font(.system(size: 10))
                        .foregroundStyle(isEditing ? Color.subtextAccent : Tokens.Text.tertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("Edit", action: onToggleEdit)
                    Divider()
                    Button("Delete", role: .destructive) { confirmDelete = true }
                } label: {
                    Text("⋮")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.vertical, 10)
        .background(isEditing ? Color.subtextAccent.opacity(0.08) : Color.clear)
        .animation(Motion.short, value: isEditing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
        }
    }

    private var ctaDeleteAlertTitle: String {
        let label = cta.heading.isEmpty
            ? (cta.name.isEmpty ? "Untitled CTA" : cta.name)
            : cta.heading
        return "Delete \"\(label)\"?"
    }
}
