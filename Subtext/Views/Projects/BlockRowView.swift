import SwiftUI

/// Flat divider-row block entry with in-place expansion panel.
/// Replaces the card+modal pattern from BlockCardView + BlockEditorPanel.
struct BlockRowView: View {
    @Binding var block: ProjectBlock
    var isExpanded: Bool
    var reorderControls: AnyView? = nil
    var onToggleExpand: () -> Void
    var onDelete: () -> Void
    var onDuplicate: () -> Void

    @State private var draftBlock: ProjectBlock
    @State private var confirmDelete = false

    init(
        block: Binding<ProjectBlock>,
        isExpanded: Bool,
        reorderControls: AnyView? = nil,
        onToggleExpand: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDuplicate: @escaping () -> Void
    ) {
        self._block = block
        self.isExpanded = isExpanded
        self.reorderControls = reorderControls
        self.onToggleExpand = onToggleExpand
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self._draftBlock = State(initialValue: block.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            rowContent
            if isExpanded {
                expansionPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                // Fresh draft when opening
                draftBlock = block
            }
        }
        .alert(deleteAlertTitle, isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This block will be removed. You can undo right after.")
        }
    }

    // MARK: - Row

    private var rowContent: some View {
        HStack(spacing: 10) {
            // Drag handle
            if let controls = reorderControls {
                controls
            } else {
                dragHandle
            }

            blockPill

            VStack(alignment: .leading, spacing: 2) {
                Text(block.inlinePreview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Text.primary)
                    .lineLimit(1)
                if !block.kindDetailText.isEmpty {
                    Text(block.kindDetailText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing actions
            HStack(spacing: 2) {
                Button(action: onToggleExpand) {
                    Text(isExpanded ? "▲" : "✎")
                        .font(.system(size: 10))
                        .foregroundStyle(isExpanded ? Color.subtextAccent : Tokens.Text.tertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse" : "Edit block")

                Menu {
                    Button("Edit", action: onToggleExpand)
                    Button("Duplicate", action: onDuplicate)
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
        .padding(.vertical, 9)
        .background(isExpanded ? Color.subtextAccent.opacity(0.08) : Color.clear)
        .animation(Motion.short, value: isExpanded)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit", action: onToggleExpand)
            Button("Duplicate", action: onDuplicate)
            Divider()
            Button("Delete", role: .destructive) { confirmDelete = true }
        }
    }

    // MARK: - Drag handle (fallback when no reorderControls)

    private var dragHandle: some View {
        VStack(spacing: 2.5) {
            Rectangle().fill(Tokens.Text.secondary.opacity(0.20)).frame(width: 12, height: 1)
            Rectangle().fill(Tokens.Text.secondary.opacity(0.20)).frame(width: 12, height: 1)
        }
        .frame(width: 18)
    }

    // MARK: - Block pill

    private var blockPill: some View {
        let c = block.kind.pillColor
        let color = Color(red: c.r, green: c.g, blue: c.b)
        return Text(block.kind.shortPillName)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .tracking(0.9)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
    }

    // MARK: - Expansion panel

    private var expansionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    blockEditorContent
                }
                .padding(16)
            }
            .frame(maxHeight: 320)

            // Cancel + Save
            HStack {
                Spacer()
                Button("Cancel") {
                    draftBlock = block
                    onToggleExpand()
                }
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.Text.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Tokens.Background.sunken)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Tokens.Border.default, lineWidth: 1)
                        )
                )
                .buttonStyle(.plain)

                Button("Save") {
                    block = draftBlock
                    onToggleExpand()
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.subtextAccent))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            Tokens.Fill.metaCard
                .overlay(alignment: .top) {
                    Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
                }
        )
    }

    // MARK: - Block editor content

    @ViewBuilder
    private var blockEditorContent: some View {
        switch draftBlock {
        case .projectSnapshot:
            ProjectSnapshotBlockEditor(block: projectSnapshotBinding)
        case .keyStats:
            KeyStatsBlockEditor(block: keyStatsBinding)
        case .goalsMetrics:
            GoalsMetricsBlockEditor(block: goalsMetricsBinding)
        case .quote:
            QuoteBlockEditor(block: quoteBinding)
        case .mediaGallery:
            MediaGalleryBlockEditor(block: mediaGalleryBinding)
        case .videoShowcase:
            VideoShowcaseBlockEditor(block: videoShowcaseBinding)
        case .cta:
            CtaBlockEditor(block: ctaBinding)
        case .body:
            BodyBlockEditor()
        case .pageHero:
            PageHeroBlockEditor(block: pageHeroBinding)
        case .headerImage:
            HeaderImageBlockEditor(block: headerImageBinding)
        case .preface:
            PrefaceBlockEditor(block: prefaceBinding)
        case .caseStudy:
            CaseStudyBlockEditor(block: caseStudyBinding)
        case .videoDetails:
            VideoDetailsBlockEditor(block: videoDetailsBinding)
        case .externalLink:
            ExternalLinkBlockEditor(block: externalLinkBinding)
        case .tagList:
            TagListBlockEditor()
        case .relatedProjects:
            RelatedProjectsBlockEditor()
        case .divider:
            DividerBlockEditor()
        }
    }

    // MARK: - Draft block bindings (mirrors BlockEditorPanel pattern)

    private var projectSnapshotBinding: Binding<ProjectSnapshotBlock> {
        Binding(
            get: { if case .projectSnapshot(let v) = draftBlock { return v }
                   return ProjectSnapshotBlock(projectTitle: "", summary: "", status: .planned, ownerTeam: "", timelineStart: "", timelineTargetCompletion: "", budgetHeadline: nil) },
            set: { draftBlock = .projectSnapshot($0) }
        )
    }
    private var keyStatsBinding: Binding<KeyStatsBlock> {
        Binding(
            get: { if case .keyStats(let v) = draftBlock { return v }; return KeyStatsBlock(title: "Key stats", items: []) },
            set: { draftBlock = .keyStats($0) }
        )
    }
    private var goalsMetricsBinding: Binding<GoalsMetricsBlock> {
        Binding(
            get: { if case .goalsMetrics(let v) = draftBlock { return v }; return GoalsMetricsBlock(title: "Goals & success metrics", items: []) },
            set: { draftBlock = .goalsMetrics($0) }
        )
    }
    private var quoteBinding: Binding<QuoteBlock> {
        Binding(
            get: { if case .quote(let v) = draftBlock { return v }; return QuoteBlock(quote: "", attributionName: nil, attributionRoleContext: nil, theme: nil) },
            set: { draftBlock = .quote($0) }
        )
    }
    private var mediaGalleryBinding: Binding<MediaGalleryBlock> {
        Binding(
            get: { if case .mediaGallery(let v) = draftBlock { return v }; return MediaGalleryBlock(title: "Media gallery", items: []) },
            set: { draftBlock = .mediaGallery($0) }
        )
    }
    private var videoShowcaseBinding: Binding<VideoShowcaseBlock> {
        Binding(
            get: {
                if case .videoShowcase(let v) = draftBlock { return v }
                return VideoShowcaseBlock(
                    variant: .cinema,
                    title: "",
                    description: nil,
                    highlights: [],
                    source: .youtube(videoId: ""),
                    ctaText: nil,
                    ctaHref: nil
                )
            },
            set: { draftBlock = .videoShowcase($0) }
        )
    }
    private var ctaBinding: Binding<CTABlock> {
        Binding(
            get: { if case .cta(let v) = draftBlock { return v }; return CTABlock(title: "", description: nil, links: []) },
            set: { draftBlock = .cta($0) }
        )
    }
    private var pageHeroBinding: Binding<PageHeroBlock> {
        Binding(
            get: { if case .pageHero(let v) = draftBlock { return v }; return PageHeroBlock() },
            set: { draftBlock = .pageHero($0) }
        )
    }
    private var headerImageBinding: Binding<HeaderImageBlock> {
        Binding(
            get: { if case .headerImage(let v) = draftBlock { return v }; return HeaderImageBlock(src: "", alt: nil) },
            set: { draftBlock = .headerImage($0) }
        )
    }
    private var prefaceBinding: Binding<PrefaceBlock> {
        Binding(
            get: { if case .preface(let v) = draftBlock { return v }; return PrefaceBlock(text: "") },
            set: { draftBlock = .preface($0) }
        )
    }
    private var caseStudyBinding: Binding<CaseStudyBlock> {
        Binding(
            get: { if case .caseStudy(let v) = draftBlock { return v }; return CaseStudyBlock(challenge: nil, approach: nil, outcome: nil, role: nil, duration: nil) },
            set: { draftBlock = .caseStudy($0) }
        )
    }
    private var videoDetailsBinding: Binding<VideoDetailsBlock> {
        Binding(
            get: { if case .videoDetails(let v) = draftBlock { return v }; return VideoDetailsBlock(runtime: nil, platform: nil, transcriptUrl: nil, credits: []) },
            set: { draftBlock = .videoDetails($0) }
        )
    }
    private var externalLinkBinding: Binding<ExternalLinkBlock> {
        Binding(
            get: { if case .externalLink(let v) = draftBlock { return v }; return ExternalLinkBlock(href: "", label: nil) },
            set: { draftBlock = .externalLink($0) }
        )
    }

    // MARK: - Helpers

    private var deleteAlertTitle: String {
        let label = block.inlinePreview.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = label.isEmpty ? block.kind.displayName : String(label.prefix(80))
        return "Delete \"\(named)\"?"
    }
}

// MARK: - Block kind detail text

extension ProjectBlock {
    /// Short secondary label shown in the flat row (e.g. "3 items", "Cinema variant").
    var kindDetailText: String {
        switch self {
        case .keyStats(let v):      return "\(v.items.count) item\(v.items.count == 1 ? "" : "s")"
        case .mediaGallery(let v):  return "\(v.items.count) item\(v.items.count == 1 ? "" : "s")"
        case .relatedProjects:      return "Auto"
        case .tagList:              return "Auto"
        case .videoShowcase(let v):
            return v.variant.displayName
        default:                    return ""
        }
    }
}
