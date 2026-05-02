import SwiftUI

struct BlockEditorPanel: View {
    @Binding var block: ProjectBlock
    var onClose: () -> Void

    static let modalSize = CGSize(width: 640, height: 600)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editor
                }
                .padding(20)
            }
        }
        .frame(width: Self.modalSize.width, height: Self.modalSize.height)
        .focusable()
        .background(
            GlassSurface(prominence: .regular, cornerRadius: SubtextUI.Radius.xLarge) {
                Color.clear
            }
        )
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: SubtextUI.Spacing.small + 2) {
            Image(systemName: block.kind.systemImage)
                .font(SubtextUI.Typography.title)
                .foregroundStyle(Color.subtextAccent)
            Text(block.kind.displayName)
                .font(SubtextUI.Typography.title)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(SubtextUI.Typography.title)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(SubtextUI.Spacing.large + 4)
    }

    @ViewBuilder
    private var editor: some View {
        switch block {
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

    private var projectSnapshotBinding: Binding<ProjectSnapshotBlock> {
        Binding(
            get: {
                if case .projectSnapshot(let snapshot) = block { return snapshot }
                return ProjectSnapshotBlock(
                    projectTitle: "",
                    summary: "",
                    status: .planned,
                    ownerTeam: "",
                    timelineStart: "",
                    timelineTargetCompletion: "",
                    budgetHeadline: nil
                )
            },
            set: { block = .projectSnapshot($0) }
        )
    }

    private var keyStatsBinding: Binding<KeyStatsBlock> {
        Binding(
            get: {
                if case .keyStats(let stats) = block { return stats }
                return KeyStatsBlock(title: "Key stats", items: [])
            },
            set: { block = .keyStats($0) }
        )
    }

    private var goalsMetricsBinding: Binding<GoalsMetricsBlock> {
        Binding(
            get: {
                if case .goalsMetrics(let goals) = block { return goals }
                return GoalsMetricsBlock(title: "Goals & success metrics", items: [])
            },
            set: { block = .goalsMetrics($0) }
        )
    }

    private var quoteBinding: Binding<QuoteBlock> {
        Binding(
            get: {
                if case .quote(let q) = block { return q }
                return QuoteBlock(
                    quote: "",
                    attributionName: nil,
                    attributionRoleContext: nil,
                    theme: nil
                )
            },
            set: { block = .quote($0) }
        )
    }

    private var mediaGalleryBinding: Binding<MediaGalleryBlock> {
        Binding(
            get: {
                if case .mediaGallery(let m) = block { return m }
                return MediaGalleryBlock(title: "Media gallery", items: [])
            },
            set: { block = .mediaGallery($0) }
        )
    }

    private var videoShowcaseBinding: Binding<VideoShowcaseBlock> {
        Binding(
            get: {
                if case .videoShowcase(let v) = block { return v }
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
            set: { block = .videoShowcase($0) }
        )
    }

    private var ctaBinding: Binding<CTABlock> {
        Binding(
            get: {
                if case .cta(let c) = block { return c }
                return CTABlock(title: "", description: nil, links: [])
            },
            set: { block = .cta($0) }
        )
    }

    private var pageHeroBinding: Binding<PageHeroBlock> {
        Binding(
            get: {
                if case .pageHero(let b) = block { return b }
                return PageHeroBlock()
            },
            set: { block = .pageHero($0) }
        )
    }

    private var headerImageBinding: Binding<HeaderImageBlock> {
        Binding(
            get: {
                if case .headerImage(let b) = block { return b }
                return HeaderImageBlock(src: "", alt: nil)
            },
            set: { block = .headerImage($0) }
        )
    }

    private var prefaceBinding: Binding<PrefaceBlock> {
        Binding(
            get: {
                if case .preface(let b) = block { return b }
                return PrefaceBlock(text: "")
            },
            set: { block = .preface($0) }
        )
    }

    private var caseStudyBinding: Binding<CaseStudyBlock> {
        Binding(
            get: {
                if case .caseStudy(let b) = block { return b }
                return CaseStudyBlock(challenge: nil, approach: nil, outcome: nil, role: nil, duration: nil)
            },
            set: { block = .caseStudy($0) }
        )
    }

    private var videoDetailsBinding: Binding<VideoDetailsBlock> {
        Binding(
            get: {
                if case .videoDetails(let b) = block { return b }
                return VideoDetailsBlock(runtime: nil, platform: nil, transcriptUrl: nil, credits: [])
            },
            set: { block = .videoDetails($0) }
        )
    }

    private var externalLinkBinding: Binding<ExternalLinkBlock> {
        Binding(
            get: {
                if case .externalLink(let b) = block { return b }
                return ExternalLinkBlock(href: "", label: nil)
            },
            set: { block = .externalLink($0) }
        )
    }
}
