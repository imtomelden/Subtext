import Foundation

/// Each entry in a project's `blocks:` YAML array.
enum ProjectBlock: Equatable, Sendable, Identifiable {
    case projectSnapshot(ProjectSnapshotBlock)
    case keyStats(KeyStatsBlock)
    case goalsMetrics(GoalsMetricsBlock)
    case narrative(NarrativeBlock)
    case quote(QuoteBlock)
    case mediaGallery(MediaGalleryBlock)
    case videoShowcase(VideoShowcaseBlock)
    case cta(CTABlock)

    var id: UUID {
        switch self {
        case .projectSnapshot(let b): b.id
        case .keyStats(let b): b.id
        case .goalsMetrics(let b): b.id
        case .narrative(let b): b.id
        case .quote(let b): b.id
        case .mediaGallery(let b): b.id
        case .videoShowcase(let b): b.id
        case .cta(let b): b.id
        }
    }

    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case projectSnapshot
        case keyStats
        case goalsMetrics
        case narrative
        case quote
        case mediaGallery
        case videoShowcase
        case cta

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .projectSnapshot: "Project Snapshot"
            case .keyStats: "Key Stats"
            case .goalsMetrics: "Goals & Success Metrics"
            case .narrative: "Narrative"
            case .quote: "Pull Quote"
            case .mediaGallery: "Media Gallery"
            case .videoShowcase: "Video Showcase"
            case .cta: "Call to Action"
            }
        }

        var systemImage: String {
            switch self {
            case .projectSnapshot: "doc.text.magnifyingglass"
            case .keyStats: "chart.bar.doc.horizontal"
            case .goalsMetrics: "target"
            case .narrative: "text.alignleft"
            case .quote: "quote.opening"
            case .mediaGallery: "photo.on.rectangle.angled"
            case .videoShowcase: "play.rectangle.fill"
            case .cta: "hand.point.up.braille.fill"
            }
        }

        /// Accent colour family for the card pill (semantic).
        var tintRGB: (r: Double, g: Double, b: Double) {
            switch self {
            case .projectSnapshot: (0.33, 0.63, 0.96)
            case .keyStats: (0.55, 0.45, 0.95)
            case .goalsMetrics: (0.34, 0.78, 0.55)
            case .narrative: (0.36, 0.83, 0.64)
            case .quote: (0.45, 0.70, 0.90)
            case .mediaGallery: (0.95, 0.55, 0.70)
            case .videoShowcase: (0.95, 0.65, 0.30)
            case .cta: (0.95, 0.80, 0.35)
            }
        }
    }

    var kind: Kind {
        switch self {
        case .projectSnapshot: .projectSnapshot
        case .keyStats: .keyStats
        case .goalsMetrics: .goalsMetrics
        case .narrative: .narrative
        case .quote: .quote
        case .mediaGallery: .mediaGallery
        case .videoShowcase: .videoShowcase
        case .cta: .cta
        }
    }

    var inlinePreview: String {
        switch self {
        case .projectSnapshot(let snapshot):
            return snapshot.projectTitle
        case .keyStats(let stats):
            return stats.items.map { "\($0.label): \($0.value)\($0.unit.map { " \($0)" } ?? "")" }.joined(separator: "  •  ")
        case .goalsMetrics(let goals):
            return goals.items.map(\.goal).joined(separator: "  •  ")
        case .narrative:
            return "(Narrative continues from the body markdown)"
        case .quote(let q):
            return q.quote
        case .mediaGallery(let m):
            return m.items.first?.alt ?? "Media grid"
        case .videoShowcase(let v):
            let titlePrefix = v.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\(v.title) · "
            switch v.source {
            case .youtube(let videoId):
                return "\(titlePrefix)YouTube (\(videoId))"
            case .vimeo(let videoId):
                return "\(titlePrefix)Vimeo (\(videoId))"
            case .file(let src, _, _, _, _):
                return titlePrefix + src
            }
        case .cta(let c):
            return c.title
        }
    }

    static func empty(of kind: Kind) -> ProjectBlock {
        switch kind {
        case .projectSnapshot: .projectSnapshot(ProjectSnapshotBlock(
            projectTitle: "",
            summary: "",
            status: .planned,
            ownerTeam: "",
            timelineStart: "",
            timelineTargetCompletion: "",
            budgetHeadline: nil
        ))
        case .keyStats: .keyStats(KeyStatsBlock(
            title: "Key stats",
            items: [
                KeyStatsBlock.Item(label: "Residents impacted", value: "", unit: nil, context: nil, lastUpdated: ISO8601Date.today()),
                KeyStatsBlock.Item(label: "Progress", value: "", unit: "%", context: nil, lastUpdated: ISO8601Date.today()),
                KeyStatsBlock.Item(label: "Spend to date", value: "", unit: nil, context: nil, lastUpdated: ISO8601Date.today())
            ]
        ))
        case .goalsMetrics: .goalsMetrics(GoalsMetricsBlock(
            title: "Goals & success metrics",
            items: [
                GoalsMetricsBlock.Item(
                    goal: "",
                    successMeasure: "",
                    baseline: "",
                    target: "",
                    reportingCadence: ""
                ),
                GoalsMetricsBlock.Item(
                    goal: "",
                    successMeasure: "",
                    baseline: "",
                    target: "",
                    reportingCadence: ""
                )
            ]
        ))
        case .narrative: .narrative(NarrativeBlock())
        case .quote: .quote(QuoteBlock(
            quote: "",
            attributionName: nil,
            attributionRoleContext: nil,
            theme: nil
        ))
        case .mediaGallery: .mediaGallery(MediaGalleryBlock(
            title: "Media gallery",
            items: [MediaGalleryBlock.Item(src: "", alt: "Image description", caption: nil, credit: nil, date: nil, location: nil)]
        ))
        case .videoShowcase: .videoShowcase(VideoShowcaseBlock(
            variant: .cinema,
            title: "",
            description: nil,
            highlights: [],
            source: .youtube(videoId: ""),
            ctaText: nil,
            ctaHref: nil
        ))
        case .cta: .cta(CTABlock(
            title: "Keep exploring",
            description: "Add a destination for this project.",
            links: [CTABlock.Link(label: "Learn more", href: "/projects")]
        ))
        }
    }
}

// MARK: - Block payloads

struct NarrativeBlock: Equatable, Sendable {
    var id: UUID = UUID()
}

struct QuoteBlock: Equatable, Sendable {
    var id: UUID = UUID()
    var quote: String
    var attributionName: String?
    var attributionRoleContext: String?
    var theme: String?
}

struct ProjectSnapshotBlock: Equatable, Sendable {
    enum Status: String, CaseIterable, Sendable, Identifiable {
        case planned
        case inProgress
        case complete

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .planned: "Planned"
            case .inProgress: "In progress"
            case .complete: "Complete"
            }
        }
    }

    var id: UUID = UUID()
    var projectTitle: String
    var summary: String
    var status: Status
    var ownerTeam: String
    var timelineStart: String
    var timelineTargetCompletion: String
    var budgetHeadline: String?
}

struct KeyStatsBlock: Equatable, Sendable {
    struct Item: Equatable, Identifiable, Sendable {
        var id: UUID = UUID()
        var label: String
        var value: String
        var unit: String?
        var context: String?
        var lastUpdated: String
    }

    var id: UUID = UUID()
    var title: String
    var items: [Item]
}

struct GoalsMetricsBlock: Equatable, Sendable {
    struct Item: Equatable, Identifiable, Sendable {
        var id: UUID = UUID()
        var goal: String
        var successMeasure: String
        var baseline: String
        var target: String
        var reportingCadence: String
    }

    var id: UUID = UUID()
    var title: String
    var items: [Item]
}

struct MediaGalleryBlock: Equatable, Sendable {
    struct Item: Equatable, Identifiable, Sendable {
        var id: UUID = UUID()
        var src: String
        var alt: String
        var caption: String?
        var credit: String?
        var date: String?
        var location: String?
    }

    var id: UUID = UUID()
    var title: String
    var items: [Item]
}

struct VideoShowcaseBlock: Equatable, Sendable {
    struct CaptionTrack: Equatable, Sendable, Identifiable {
        var id: UUID = UUID()
        var src: String
        var srclang: String
        var label: String
        var isDefault: Bool
    }

    enum Variant: String, CaseIterable, Sendable, Identifiable {
        case cinema
        case device
        case split

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .cinema: "Cinema"
            case .device: "Device"
            case .split: "Split"
            }
        }
    }

    enum Source: Equatable, Sendable {
        case youtube(videoId: String)
        case vimeo(videoId: String)
        case file(
            src: String,
            poster: String?,
            mimeType: String?,
            fallbackUrl: String?,
            captions: [CaptionTrack]
        )

        var kindLabel: String {
            switch self {
            case .youtube: "YouTube"
            case .vimeo: "Vimeo"
            case .file: "File"
            }
        }
    }

    var id: UUID = UUID()
    var variant: Variant
    var title: String
    var description: String?
    var highlights: [String]
    var source: Source
    var ctaText: String?
    var ctaHref: String?
}

struct CTABlock: Equatable, Sendable {
    struct Link: Equatable, Identifiable, Sendable {
        var id: UUID = UUID()
        var label: String
        var href: String
    }

    var id: UUID = UUID()
    var title: String
    var description: String?
    var links: [Link]
}

// MARK: - Round-trip equality (ignore editor-only IDs)

extension ProjectBlock {
    static func == (lhs: ProjectBlock, rhs: ProjectBlock) -> Bool {
        switch (lhs, rhs) {
        case (.projectSnapshot(let l), .projectSnapshot(let r)): l == r
        case (.keyStats(let l), .keyStats(let r)): l == r
        case (.goalsMetrics(let l), .goalsMetrics(let r)): l == r
        case (.narrative(let l), .narrative(let r)): l == r
        case (.quote(let l), .quote(let r)): l == r
        case (.mediaGallery(let l), .mediaGallery(let r)): l == r
        case (.videoShowcase(let l), .videoShowcase(let r)): l == r
        case (.cta(let l), .cta(let r)): l == r
        default: false
        }
    }
}

extension NarrativeBlock {
    static func == (lhs: NarrativeBlock, rhs: NarrativeBlock) -> Bool { true }
}

extension QuoteBlock {
    static func == (lhs: QuoteBlock, rhs: QuoteBlock) -> Bool {
        lhs.quote == rhs.quote
            && lhs.attributionName == rhs.attributionName
            && lhs.attributionRoleContext == rhs.attributionRoleContext
            && lhs.theme == rhs.theme
    }
}

extension ProjectSnapshotBlock {
    static func == (lhs: ProjectSnapshotBlock, rhs: ProjectSnapshotBlock) -> Bool {
        lhs.projectTitle == rhs.projectTitle
            && lhs.summary == rhs.summary
            && lhs.status == rhs.status
            && lhs.ownerTeam == rhs.ownerTeam
            && lhs.timelineStart == rhs.timelineStart
            && lhs.timelineTargetCompletion == rhs.timelineTargetCompletion
            && lhs.budgetHeadline == rhs.budgetHeadline
    }
}

extension KeyStatsBlock.Item {
    static func == (lhs: KeyStatsBlock.Item, rhs: KeyStatsBlock.Item) -> Bool {
        lhs.label == rhs.label
            && lhs.value == rhs.value
            && lhs.unit == rhs.unit
            && lhs.context == rhs.context
            && lhs.lastUpdated == rhs.lastUpdated
    }
}

extension KeyStatsBlock {
    static func == (lhs: KeyStatsBlock, rhs: KeyStatsBlock) -> Bool {
        lhs.title == rhs.title
            && lhs.items == rhs.items
    }
}

extension GoalsMetricsBlock.Item {
    static func == (lhs: GoalsMetricsBlock.Item, rhs: GoalsMetricsBlock.Item) -> Bool {
        lhs.goal == rhs.goal
            && lhs.successMeasure == rhs.successMeasure
            && lhs.baseline == rhs.baseline
            && lhs.target == rhs.target
            && lhs.reportingCadence == rhs.reportingCadence
    }
}

extension GoalsMetricsBlock {
    static func == (lhs: GoalsMetricsBlock, rhs: GoalsMetricsBlock) -> Bool {
        lhs.title == rhs.title
            && lhs.items == rhs.items
    }
}

extension MediaGalleryBlock.Item {
    static func == (lhs: MediaGalleryBlock.Item, rhs: MediaGalleryBlock.Item) -> Bool {
        lhs.src == rhs.src
            && lhs.alt == rhs.alt
            && lhs.caption == rhs.caption
            && lhs.credit == rhs.credit
            && lhs.date == rhs.date
            && lhs.location == rhs.location
    }
}

extension MediaGalleryBlock {
    static func == (lhs: MediaGalleryBlock, rhs: MediaGalleryBlock) -> Bool {
        lhs.title == rhs.title
            && lhs.items == rhs.items
    }
}

extension VideoShowcaseBlock.CaptionTrack {
    static func == (lhs: VideoShowcaseBlock.CaptionTrack, rhs: VideoShowcaseBlock.CaptionTrack) -> Bool {
        lhs.src == rhs.src
            && lhs.srclang == rhs.srclang
            && lhs.label == rhs.label
            && lhs.isDefault == rhs.isDefault
    }
}

extension VideoShowcaseBlock.Source {
    static func == (lhs: VideoShowcaseBlock.Source, rhs: VideoShowcaseBlock.Source) -> Bool {
        switch (lhs, rhs) {
        case (.youtube(let lId), .youtube(let rId)):
            lId == rId
        case (.vimeo(let lId), .vimeo(let rId)):
            lId == rId
        case (
            .file(
                src: let lSrc,
                poster: let lPoster,
                mimeType: let lMimeType,
                fallbackUrl: let lFallback,
                captions: let lCaptions
            ),
            .file(
                src: let rSrc,
                poster: let rPoster,
                mimeType: let rMimeType,
                fallbackUrl: let rFallback,
                captions: let rCaptions
            )
        ):
            lSrc == rSrc
                && lPoster == rPoster
                && lMimeType == rMimeType
                && lFallback == rFallback
                && lCaptions == rCaptions
        default:
            false
        }
    }
}

extension VideoShowcaseBlock {
    static func == (lhs: VideoShowcaseBlock, rhs: VideoShowcaseBlock) -> Bool {
        lhs.variant == rhs.variant
            && lhs.title == rhs.title
            && lhs.description == rhs.description
            && lhs.highlights == rhs.highlights
            && lhs.source == rhs.source
            && lhs.ctaText == rhs.ctaText
            && lhs.ctaHref == rhs.ctaHref
    }
}

extension CTABlock.Link {
    static func == (lhs: CTABlock.Link, rhs: CTABlock.Link) -> Bool {
        lhs.label == rhs.label
            && lhs.href == rhs.href
    }
}

extension CTABlock {
    static func == (lhs: CTABlock, rhs: CTABlock) -> Bool {
        lhs.title == rhs.title
            && lhs.description == rhs.description
            && lhs.links == rhs.links
    }
}
