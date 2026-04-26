import SwiftUI

struct BlockEditorPanel: View {
    @Binding var block: ProjectBlock
    var onClose: () -> Void

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
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: block.kind.systemImage)
                .font(.title3)
                .foregroundStyle(Color.subtextAccent)
            Text(block.kind.displayName)
                .font(.title3.weight(.semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
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
        case .narrative:
            NarrativeBlockEditor()
        case .quote:
            QuoteBlockEditor(block: quoteBinding)
        case .mediaGallery:
            MediaGalleryBlockEditor(block: mediaGalleryBinding)
        case .videoShowcase:
            VideoShowcaseBlockEditor(block: videoShowcaseBinding)
        case .cta:
            CtaBlockEditor(block: ctaBinding)
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
}
