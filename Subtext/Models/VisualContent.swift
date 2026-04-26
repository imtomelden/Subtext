import Foundation

/// Every splash section has exactly one `visual`. The `type` tag in the JSON
/// selects the shape, and we model it as a Swift enum with associated values.
enum VisualContent: Equatable, Sendable {
    case photo(PhotoVisual)
    case ticket(TicketVisual)
    case speech(SpeechVisual)
    case scramble(ScrambleVisual)
    case terminal(TerminalVisual)

    /// Matches the strings used in `splash.json`'s `visual.type`.
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case photo
        case ticket
        case speech
        case scramble
        case terminal

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .photo: "Photo"
            case .ticket: "Ticket"
            case .speech: "Speech"
            case .scramble: "Scramble"
            case .terminal: "Terminal"
            }
        }

        var systemImage: String {
            switch self {
            case .photo: "photo.fill"
            case .ticket: "ticket.fill"
            case .speech: "bubble.left.and.bubble.right.fill"
            case .scramble: "text.word.spacing"
            case .terminal: "terminal.fill"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .photo: .photo
        case .ticket: .ticket
        case .speech: .speech
        case .scramble: .scramble
        case .terminal: .terminal
        }
    }

    static func empty(of kind: Kind) -> VisualContent {
        switch kind {
        case .photo:
            return .photo(PhotoVisual(src: "", alt: ""))
        case .ticket:
            return .ticket(TicketVisual(
                passenger: "",
                route: "",
                from: "",
                to: "",
                fromCode: "",
                toCode: "",
                date: ""
            ))
        case .speech:
            return .speech(SpeechVisual(messages: []))
        case .scramble:
            return .scramble(ScrambleVisual(words: []))
        case .terminal:
            return .terminal(TerminalVisual(title: "", lines: []))
        }
    }
}

struct PhotoVisual: Equatable, Codable, Sendable {
    var src: String
    var alt: String
}

struct TicketVisual: Equatable, Codable, Sendable {
    var passenger: String
    var route: String
    var from: String
    var to: String
    var fromCode: String
    var toCode: String
    var date: String
}

struct SpeechVisual: Equatable, Codable, Sendable {
    var messages: [SpeechMessage]
}

struct SpeechMessage: Equatable, Codable, Identifiable, Sendable {
    enum Side: String, Codable, CaseIterable, Sendable, Identifiable {
        case left
        case right

        var id: String { rawValue }
    }

    /// SwiftUI identity only — not stored in `splash.json` (see `CodingKeys`).
    var id: UUID = UUID()
    var side: Side
    var text: String

    enum CodingKeys: String, CodingKey {
        case side
        case text
    }

    init(id: UUID = UUID(), side: Side, text: String) {
        self.id = id
        self.side = side
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.side = try container.decode(Side.self, forKey: .side)
        self.text = try container.decode(String.self, forKey: .text)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(side, forKey: .side)
        try container.encode(text, forKey: .text)
    }

    /// JSON omits `id`; decode assigns a fresh UUID. Equality for CMS round-trip
    /// and editing must depend only on persisted fields.
    static func == (lhs: SpeechMessage, rhs: SpeechMessage) -> Bool {
        lhs.side == rhs.side && lhs.text == rhs.text
    }
}

struct ScrambleVisual: Equatable, Codable, Sendable {
    var words: [String]
}

struct TerminalVisual: Equatable, Codable, Sendable {
    var title: String
    var lines: [String]
}

// MARK: - Codable

extension VisualContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum TypeTag: String, Codable {
        case photo, ticket, speech, scramble, terminal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try container.decode(TypeTag.self, forKey: .type)
        let single = try decoder.singleValueContainer()

        switch tag {
        case .photo:
            self = .photo(try single.decode(PhotoVisualWire.self).toModel())
        case .ticket:
            self = .ticket(try single.decode(TicketVisualWire.self).toModel())
        case .speech:
            self = .speech(try single.decode(SpeechVisualWire.self).toModel())
        case .scramble:
            self = .scramble(try single.decode(ScrambleVisualWire.self).toModel())
        case .terminal:
            self = .terminal(try single.decode(TerminalVisualWire.self).toModel())
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .photo(let p):
            try PhotoVisualWire(model: p).encode(to: encoder)
        case .ticket(let t):
            try TicketVisualWire(model: t).encode(to: encoder)
        case .speech(let s):
            try SpeechVisualWire(model: s).encode(to: encoder)
        case .scramble(let s):
            try ScrambleVisualWire(model: s).encode(to: encoder)
        case .terminal(let t):
            try TerminalVisualWire(model: t).encode(to: encoder)
        }
    }
}

// MARK: - Wire shapes (exact JSON envelope with the `type` tag inline)

private struct PhotoVisualWire: Codable {
    var type: String = "photo"
    var src: String
    var alt: String
    init(model: PhotoVisual) { self.src = model.src; self.alt = model.alt }
    func toModel() -> PhotoVisual { PhotoVisual(src: src, alt: alt) }
}

private struct TicketVisualWire: Codable {
    var type: String = "ticket"
    var passenger: String
    var route: String
    var from: String
    var to: String
    var fromCode: String
    var toCode: String
    var date: String

    enum CodingKeys: String, CodingKey {
        case type
        case passenger
        case route
        case from
        case to
        case fromCode
        case toCode
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "ticket"
        self.passenger = try container.decode(String.self, forKey: .passenger)
        self.route = try container.decode(String.self, forKey: .route)
        self.from = try container.decode(String.self, forKey: .from)
        self.to = try container.decode(String.self, forKey: .to)
        self.fromCode = try container.decodeIfPresent(String.self, forKey: .fromCode) ?? ""
        self.toCode = try container.decodeIfPresent(String.self, forKey: .toCode) ?? ""
        self.date = try container.decode(String.self, forKey: .date)
    }

    init(model: TicketVisual) {
        self.passenger = model.passenger
        self.route = model.route
        self.from = model.from
        self.to = model.to
        self.fromCode = model.fromCode
        self.toCode = model.toCode
        self.date = model.date
    }
    func toModel() -> TicketVisual {
        TicketVisual(
            passenger: passenger,
            route: route,
            from: from,
            to: to,
            fromCode: fromCode,
            toCode: toCode,
            date: date
        )
    }
}

private struct SpeechVisualWire: Codable {
    var type: String = "speech"
    var messages: [SpeechMessage]
    init(model: SpeechVisual) { self.messages = model.messages }
    func toModel() -> SpeechVisual { SpeechVisual(messages: messages) }
}

private struct ScrambleVisualWire: Codable {
    var type: String = "scramble"
    var words: [String]
    init(model: ScrambleVisual) { self.words = model.words }
    func toModel() -> ScrambleVisual { ScrambleVisual(words: words) }
}

private struct TerminalVisualWire: Codable {
    var type: String = "terminal"
    var title: String
    var lines: [String]
    init(model: TerminalVisual) { self.title = model.title; self.lines = model.lines }
    func toModel() -> TerminalVisual { TerminalVisual(title: title, lines: lines) }
}
