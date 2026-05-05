import Foundation

/// Exactly the shape of the YAML block at the top of every `*.mdx` file.
/// The website's `projectCollectionSchema` is the source of truth; any
/// additions there should be reflected here.
struct ProjectFrontmatter: Equatable, Sendable {
    enum Ownership: String, Codable, CaseIterable, Sendable, Identifiable {
        case work
        case personal

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .work: "Work"
            case .personal: "Personal"
            }
        }
    }

    struct Hero: Equatable, Codable, Sendable {
        var eyebrow: String?
        var title: String?
        var subtitle: String?

        var isEmpty: Bool {
            (eyebrow ?? "").isEmpty
                && (title ?? "").isEmpty
                && (subtitle ?? "").isEmpty
        }
    }

    struct VideoMeta: Equatable, Codable, Sendable {
        var runtime: String?
        var platform: String?
        var transcriptUrl: String?
        var credits: [String]

        var isEmpty: Bool {
            (runtime ?? "").isEmpty
                && (platform ?? "").isEmpty
                && (transcriptUrl ?? "").isEmpty
                && credits.isEmpty
        }
    }

    var title: String
    var slug: String
    var description: String
    /// Stored as the literal string from the MDX ("2026-04-11" or similar).
    var date: String
    var ownership: Ownership
    var tags: [String]
    var thumbnail: String?
    var headerImage: String?
    var externalUrl: String?
    var featured: Bool
    var draft: Bool
    var archived: Bool
    var role: String?
    var duration: String?
    var impact: String?
    var challenge: String?
    var approach: String?
    var outcome: String?
    var videoMeta: VideoMeta?
    var hero: Hero?
    var blocks: [ProjectBlock]

    static func newDraft(slug: String, title: String, ownership: Ownership = .work) -> ProjectFrontmatter {
        // Default layout ring must match `MDXParser.synthesiseLayoutBlocksIfNeeded` for the
        // same top-level fields; otherwise the first save fails round-trip validation because
        // parse re-injects these blocks when `blocks:` is absent from the file.
        ProjectFrontmatter(
            title: title,
            slug: slug,
            description: "Add a short description",
            date: ISO8601Date.today(),
            ownership: ownership,
            tags: [],
            thumbnail: nil,
            headerImage: nil,
            externalUrl: nil,
            featured: false,
            draft: false,
            archived: false,
            role: nil,
            duration: nil,
            impact: nil,
            challenge: nil,
            approach: nil,
            outcome: nil,
            videoMeta: nil,
            hero: nil,
            blocks: [
                .body(BodyBlock()),
                .tagList(TagListBlock()),
                .relatedProjects(RelatedProjectsBlock()),
            ]
        )
    }
}

/// Represents an entire `.mdx` file — frontmatter plus the remaining markdown
/// body. `fileName` is the on-disk filename (no directory), which may differ
/// from `slug` if the filename was generated before slug was set.
struct ProjectDocument: Identifiable, Equatable, Sendable {
    var id: String { fileName }
    var fileName: String
    var frontmatter: ProjectFrontmatter
    var body: String
}

enum ISO8601Date {
    /// Single shared formatter for the literal `YYYY-MM-DD` strings we
    /// round-trip through frontmatter. Locked to POSIX + ISO calendar so
    /// it's stable regardless of the user's locale.
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    static func today() -> String {
        formatter.string(from: Date())
    }

    /// Parses `YYYY-MM-DD`. Returns `nil` for empty strings or malformed dates
    /// so callers can fall back to the raw text editor.
    static func parse(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return formatter.date(from: trimmed)
    }

    static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
