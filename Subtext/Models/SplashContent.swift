import Foundation

/// Root of `splash.json`.
struct SplashContent: Equatable, Sendable {
    var sections: [SplashSection]
    var ctas: [SplashCTA]

    static let empty = SplashContent(sections: [], ctas: [])
}

struct SplashSection: Identifiable, Equatable, Sendable {
    enum ImagePosition: String, Codable, CaseIterable, Sendable, Identifiable {
        case left
        case right

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .left: "Image left"
            case .right: "Image right"
            }
        }
    }

    var id: String
    var heading: String
    var subtitle: String?
    var bodyParagraphs: [String]
    var imagePosition: ImagePosition
    var isHero: Bool
    var visual: VisualContent
    /// Opaque JSON object consumed by the Astro site (passed to
    /// `JourneySection`). Subtext has no editor for it yet, but we
    /// decode and re-encode it verbatim so adding a `transition` block
    /// on disk (or via the site) isn't silently erased on the next save.
    var transition: JSONValue?
    /// Optional additional visual options consumed by the site. We don't
    /// edit these in Subtext yet, but preserve them losslessly on save.
    var visualAlternates: [JSONValue]?

    /// A short preview for card display.
    var previewText: String {
        bodyParagraphs.first ?? subtitle ?? ""
    }

    /// Friendly display label for the well-known home sections.
    var sectionLabel: String {
        switch id.lowercased() {
        case "hero": "Hero"
        case "transplant": "Transplant"
        case "communicator": "Communicator"
        case "writer": "Writer"
        case "tinkerer": "Tinkerer"
        case "blogger": "Blogger"
        default: heading.isEmpty ? "Section" : heading
        }
    }

    /// Distinct icon for each home section label to make cards easier to scan.
    var sectionSystemImage: String {
        switch id.lowercased() {
        case "hero": "person.crop.square.fill"
        case "transplant": "tram.fill"
        case "communicator": "megaphone.fill"
        case "writer": "pencil.and.scribble"
        case "tinkerer": "chevron.left.forwardslash.chevron.right"
        case "blogger": "newspaper.fill"
        default: visual.kind.systemImage
        }
    }
}

struct SplashCTA: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var heading: String
    var subtitle: String
    var href: String
}

// MARK: - Codable

extension SplashContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case sections
        case ctas
    }
}

extension SplashSection: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case heading
        case subtitle
        case bodyParagraphs
        case imagePosition
        case isHero
        case visual
        case transition
        case visualAlternates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.heading = try container.decode(String.self, forKey: .heading)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.bodyParagraphs = try container.decodeIfPresent([String].self, forKey: .bodyParagraphs) ?? []
        self.imagePosition = try container.decodeIfPresent(ImagePosition.self, forKey: .imagePosition) ?? .left
        self.isHero = try container.decodeIfPresent(Bool.self, forKey: .isHero) ?? false
        self.visual = try container.decode(VisualContent.self, forKey: .visual)
        self.transition = try container.decodeIfPresent(JSONValue.self, forKey: .transition)
        self.visualAlternates = try container.decodeIfPresent([JSONValue].self, forKey: .visualAlternates)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(heading, forKey: .heading)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encode(bodyParagraphs, forKey: .bodyParagraphs)
        try container.encode(imagePosition, forKey: .imagePosition)
        try container.encode(isHero, forKey: .isHero)
        try container.encode(visual, forKey: .visual)
        try container.encodeIfPresent(transition, forKey: .transition)
        try container.encodeIfPresent(visualAlternates, forKey: .visualAlternates)
    }
}

extension SplashCTA: Codable {}

// MARK: - Builders

extension SplashSection {
    enum AddSectionOption: Hashable, Identifiable {
        case visualKind(VisualContent.Kind)

        var id: String {
            switch self {
            case .visualKind(let kind):
                return "kind:\(kind.rawValue)"
            }
        }

        var displayName: String {
            switch self {
            case .visualKind(let kind):
                return kind.displayName
            }
        }

        var systemImage: String {
            switch self {
            case .visualKind(let kind):
                return kind.systemImage
            }
        }
    }

    static let addSectionOptions: [AddSectionOption] = {
        VisualContent.Kind.allCases.map { .visualKind($0) }
    }()

    static func newDraft(kind: VisualContent.Kind) -> SplashSection {
        SplashSection(
            id: "section-\(shortID())",
            heading: "New section",
            subtitle: nil,
            bodyParagraphs: [""],
            imagePosition: .left,
            isHero: false,
            visual: .empty(of: kind),
            transition: nil,
            visualAlternates: nil
        )
    }

    static func newDraft(option: AddSectionOption) -> SplashSection {
        switch option {
        case .visualKind(let kind):
            return newDraft(kind: kind)
        }
    }
}

extension SplashCTA {
    static func newDraft() -> SplashCTA {
        SplashCTA(
            id: "cta-\(shortID())",
            name: "New CTA",
            heading: "",
            subtitle: "",
            href: ""
        )
    }
}

/// 8-character hex suffix for generated IDs.
func shortID() -> String {
    String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
}
