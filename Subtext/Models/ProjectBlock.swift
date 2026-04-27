import Foundation

/// Each entry in a project's `blocks:` YAML array.
enum ProjectBlock: Equatable, Sendable, Identifiable {
    case projectSnapshot(ProjectSnapshotBlock)
    case keyStats(KeyStatsBlock)
    case goalsMetrics(GoalsMetricsBlock)
    case quote(QuoteBlock)
    case mediaGallery(MediaGalleryBlock)
    case videoShowcase(VideoShowcaseBlock)
    case cta(CTABlock)
    // Layout blocks (page chrome as ordered cards)
    case body(BodyBlock)
    case pageHero(PageHeroBlock)
    case headerImage(HeaderImageBlock)
    case caseStudy(CaseStudyBlock)
    case videoDetails(VideoDetailsBlock)
    case externalLink(ExternalLinkBlock)
    case tagList(TagListBlock)
    case relatedProjects(RelatedProjectsBlock)

    var id: UUID {
        switch self {
        case .projectSnapshot(let b): b.id
        case .keyStats(let b): b.id
        case .goalsMetrics(let b): b.id
        case .quote(let b): b.id
        case .mediaGallery(let b): b.id
        case .videoShowcase(let b): b.id
        case .cta(let b): b.id
        case .body(let b): b.id
        case .pageHero(let b): b.id
        case .headerImage(let b): b.id
        case .caseStudy(let b): b.id
        case .videoDetails(let b): b.id
        case .externalLink(let b): b.id
        case .tagList(let b): b.id
        case .relatedProjects(let b): b.id
        }
    }

    /// True for blocks that participate in the “layout” ring (drives default synthesis when absent).
    var isLayoutBlock: Bool {
        switch self {
        case .body, .pageHero, .headerImage, .caseStudy, .videoDetails, .externalLink, .tagList, .relatedProjects:
            return true
        default:
            return false
        }
    }

    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case projectSnapshot
        case keyStats
        case goalsMetrics
        case quote
        case mediaGallery
        case videoShowcase
        case cta
        case body
        case pageHero
        case headerImage
        case caseStudy
        case videoDetails
        case externalLink
        case tagList
        case relatedProjects

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .projectSnapshot: "Project Snapshot"
            case .keyStats: "Key Stats"
            case .goalsMetrics: "Goals & Success Metrics"
            case .quote: "Pull Quote"
            case .mediaGallery: "Media Gallery"
            case .videoShowcase: "Video Showcase"
            case .cta: "Call to Action"
            case .body: "MDX body"
            case .pageHero: "Page hero"
            case .headerImage: "Header image"
            case .caseStudy: "Case study"
            case .videoDetails: "Video details"
            case .externalLink: "External link"
            case .tagList: "Tag list"
            case .relatedProjects: "Related projects"
            }
        }

        var systemImage: String {
            switch self {
            case .projectSnapshot: "doc.text.magnifyingglass"
            case .keyStats: "chart.bar.doc.horizontal"
            case .goalsMetrics: "target"
            case .quote: "quote.opening"
            case .mediaGallery: "photo.on.rectangle.angled"
            case .videoShowcase: "play.rectangle.fill"
            case .cta: "hand.point.up.braille.fill"
            case .body: "doc.plaintext"
            case .pageHero: "sparkles"
            case .headerImage: "photo"
            case .caseStudy: "list.bullet.rectangle"
            case .videoDetails: "film"
            case .externalLink: "link"
            case .tagList: "tag"
            case .relatedProjects: "rectangle.grid.1x2"
            }
        }

        /// Accent colour family for the card pill (semantic).
        var tintRGB: (r: Double, g: Double, b: Double) {
            switch self {
            case .projectSnapshot: (0.33, 0.63, 0.96)
            case .keyStats: (0.55, 0.45, 0.95)
            case .goalsMetrics: (0.34, 0.78, 0.55)
            case .quote: (0.45, 0.70, 0.90)
            case .mediaGallery: (0.95, 0.55, 0.70)
            case .videoShowcase: (0.95, 0.65, 0.30)
            case .cta: (0.95, 0.80, 0.35)
            case .body: (0.40, 0.82, 0.68)
            case .pageHero: (0.55, 0.75, 0.98)
            case .headerImage: (0.90, 0.60, 0.45)
            case .caseStudy: (0.50, 0.85, 0.90)
            case .videoDetails: (0.75, 0.55, 0.95)
            case .externalLink: (0.45, 0.78, 0.55)
            case .tagList: (0.65, 0.70, 0.85)
            case .relatedProjects: (0.85, 0.50, 0.55)
            }
        }
    }

    var kind: Kind {
        switch self {
        case .projectSnapshot: .projectSnapshot
        case .keyStats: .keyStats
        case .goalsMetrics: .goalsMetrics
        case .quote: .quote
        case .mediaGallery: .mediaGallery
        case .videoShowcase: .videoShowcase
        case .cta: .cta
        case .body: .body
        case .pageHero: .pageHero
        case .headerImage: .headerImage
        case .caseStudy: .caseStudy
        case .videoDetails: .videoDetails
        case .externalLink: .externalLink
        case .tagList: .tagList
        case .relatedProjects: .relatedProjects
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
        case .body:
            return "Renders the MDX body"
        case .pageHero(let h):
            return [h.eyebrow, h.title, h.subtitle].compactMap { $0 }.first.map { $0 } ?? "Hero"
        case .headerImage(let i):
            return i.src.isEmpty ? "No image" : i.src
        case .caseStudy(let c):
            return [c.challenge, c.role].compactMap { $0 }.first.map { $0 } ?? "Case study"
        case .videoDetails(let v):
            return [v.runtime, v.platform].compactMap { $0 }.joined(separator: " · ")
        case .externalLink(let e):
            return e.href.isEmpty ? "No URL" : e.href
        case .tagList:
            return "Project tags"
        case .relatedProjects:
            return "Related projects (auto)"
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
        case .body: .body(BodyBlock())
        case .pageHero: .pageHero(PageHeroBlock(eyebrow: nil, title: nil, subtitle: nil))
        case .headerImage: .headerImage(HeaderImageBlock(src: "", alt: nil))
        case .caseStudy: .caseStudy(CaseStudyBlock(
            challenge: nil, approach: nil, outcome: nil, role: nil, duration: nil
        ))
        case .videoDetails: .videoDetails(VideoDetailsBlock(
            runtime: nil, platform: nil, transcriptUrl: nil, credits: []
        ))
        case .externalLink: .externalLink(ExternalLinkBlock(href: "", label: nil))
        case .tagList: .tagList(TagListBlock())
        case .relatedProjects: .relatedProjects(RelatedProjectsBlock())
        }
    }
}

// MARK: - Layout block payloads

struct BodyBlock: Equatable, Sendable {
    var id: UUID = UUID()
}

struct PageHeroBlock: Equatable, Sendable {
    var id: UUID = UUID()
    var eyebrow: String?
    var title: String?
    var subtitle: String?

    var isEmpty: Bool {
        (eyebrow ?? "").isEmpty
            && (title ?? "").isEmpty
            && (subtitle ?? "").isEmpty
    }
}

struct HeaderImageBlock: Equatable, Sendable {
    var id: UUID = UUID()
    var src: String
    var alt: String?
}

struct CaseStudyBlock: Equatable, Sendable {
    var id: UUID = UUID()
    var challenge: String?
    var approach: String?
    var outcome: String?
    var role: String?
    var duration: String?
}

struct VideoDetailsBlock: Equatable, Sendable {
    var id: UUID = UUID()
    var runtime: String?
    var platform: String?
    var transcriptUrl: String?
    var credits: [String]
}

struct ExternalLinkBlock: Equatable, Sendable {
    var id: UUID = UUID()
    var href: String
    var label: String?
}

struct TagListBlock: Equatable, Sendable {
    var id: UUID = UUID()
}

struct RelatedProjectsBlock: Equatable, Sendable {
    var id: UUID = UUID()
}

// MARK: - Block payloads

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
        case (.quote(let l), .quote(let r)): l == r
        case (.mediaGallery(let l), .mediaGallery(let r)): l == r
        case (.videoShowcase(let l), .videoShowcase(let r)): l == r
        case (.cta(let l), .cta(let r)): l == r
        case (.body(let l), .body(let r)): l == r
        case (.pageHero(let l), .pageHero(let r)): l == r
        case (.headerImage(let l), .headerImage(let r)): l == r
        case (.caseStudy(let l), .caseStudy(let r)): l == r
        case (.videoDetails(let l), .videoDetails(let r)): l == r
        case (.externalLink(let l), .externalLink(let r)): l == r
        case (.tagList(let l), .tagList(let r)): l == r
        case (.relatedProjects(let l), .relatedProjects(let r)): l == r
        default: false
        }
    }
}

extension BodyBlock {
    static func == (lhs: BodyBlock, rhs: BodyBlock) -> Bool { true }
}

extension PageHeroBlock {
    static func == (lhs: PageHeroBlock, rhs: PageHeroBlock) -> Bool {
        lhs.eyebrow == rhs.eyebrow
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
    }
}

extension HeaderImageBlock {
    static func == (lhs: HeaderImageBlock, rhs: HeaderImageBlock) -> Bool {
        lhs.src == rhs.src && lhs.alt == rhs.alt
    }
}

extension CaseStudyBlock {
    static func == (lhs: CaseStudyBlock, rhs: CaseStudyBlock) -> Bool {
        lhs.challenge == rhs.challenge
            && lhs.approach == rhs.approach
            && lhs.outcome == rhs.outcome
            && lhs.role == rhs.role
            && lhs.duration == rhs.duration
    }
}

extension VideoDetailsBlock {
    static func == (lhs: VideoDetailsBlock, rhs: VideoDetailsBlock) -> Bool {
        lhs.runtime == rhs.runtime
            && lhs.platform == rhs.platform
            && lhs.transcriptUrl == rhs.transcriptUrl
            && lhs.credits == rhs.credits
    }
}

extension ExternalLinkBlock {
    static func == (lhs: ExternalLinkBlock, rhs: ExternalLinkBlock) -> Bool {
        lhs.href == rhs.href && lhs.label == rhs.label
    }
}

extension TagListBlock {
    static func == (lhs: TagListBlock, rhs: TagListBlock) -> Bool { true }
}

extension RelatedProjectsBlock {
    static func == (lhs: RelatedProjectsBlock, rhs: RelatedProjectsBlock) -> Bool { true }
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
