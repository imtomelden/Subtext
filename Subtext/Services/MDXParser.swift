import Foundation

struct LegacyBlockMigration {
    struct LegacyBlockHit: Equatable {
        let index: Int
        let legacyType: String
        let canonicalType: String
    }

    struct MigrationResult: Equatable {
        let content: String
        let legacyTypeChanges: [LegacyBlockHit]
        let repairedEmptyVideoIdCount: Int

        var didChange: Bool {
            !legacyTypeChanges.isEmpty || repairedEmptyVideoIdCount > 0
        }
    }

    /// `mediaGrid` is the on-disk alias; `mediaGallery` is the canonical type in the model.
    private static let preflightLegacyTypeMap: [String: String] = [
        "mediaGallery": "mediaGrid",
    ]

    // Used by parser so aliases decode to one internal model shape.
    private static let parserAliasMap: [String: String] = [
        "statCards": "keyStats",
        "mediaGrid": "mediaGallery"
    ]

    private static let blockTypeLinePattern = #"""
(?m)^(\s*-\s*type:\s*)(["']?)([A-Za-z][A-Za-z0-9_-]*)(["']?)\s*$
"""#

    static func preflightCanonicalType(for rawType: String) -> String {
        preflightLegacyTypeMap[rawType] ?? rawType
    }

    static func parserCanonicalType(for rawType: String) -> String {
        parserAliasMap[rawType] ?? rawType
    }

    static func scanLegacyBlockTypes(in frontmatter: String) -> [LegacyBlockHit] {
        let nsrange = NSRange(frontmatter.startIndex..<frontmatter.endIndex, in: frontmatter)
        guard let regex = try? NSRegularExpression(pattern: blockTypeLinePattern, options: []) else {
            return []
        }

        var found: [LegacyBlockHit] = []
        let matches = regex.matches(in: frontmatter, options: [], range: nsrange)
        for (blockIndex, match) in matches.enumerated() {
            guard match.numberOfRanges > 3,
                  let typeRange = Range(match.range(at: 3), in: frontmatter) else {
                continue
            }
            let rawType = String(frontmatter[typeRange])
            guard let canonicalType = preflightLegacyTypeMap[rawType] else { continue }
            found.append(
                LegacyBlockHit(
                    index: blockIndex,
                    legacyType: rawType,
                    canonicalType: canonicalType
                )
            )
        }
        return found
    }

    static func migrate(frontmatter: String) -> MigrationResult {
        let nsrange = NSRange(frontmatter.startIndex..<frontmatter.endIndex, in: frontmatter)
        guard let regex = try? NSRegularExpression(pattern: blockTypeLinePattern, options: []) else {
            return MigrationResult(content: frontmatter, legacyTypeChanges: [], repairedEmptyVideoIdCount: 0)
        }

        let matches = regex.matches(in: frontmatter, options: [], range: nsrange)
        var migrated = frontmatter
        var legacyHits: [LegacyBlockHit] = []
        for (blockIndex, match) in matches.enumerated().reversed() {
            guard match.numberOfRanges > 3,
                  let typeRange = Range(match.range(at: 3), in: migrated) else {
                continue
            }
            let rawType = String(migrated[typeRange])
            guard let canonicalType = preflightLegacyTypeMap[rawType] else { continue }
            migrated.replaceSubrange(typeRange, with: canonicalType)
            legacyHits.append(
                LegacyBlockHit(index: blockIndex, legacyType: rawType, canonicalType: canonicalType)
            )
        }
        legacyHits.sort { $0.index < $1.index }

        var repairedVideoIdCount = 0
        if let emptyVideoRegex = try? NSRegularExpression(
            pattern: #"(?m)^(\s*)videoId:\s*["']?\s*["']?\s*$"#,
            options: []
        ) {
            let videoRange = NSRange(migrated.startIndex..<migrated.endIndex, in: migrated)
            repairedVideoIdCount = emptyVideoRegex.numberOfMatches(in: migrated, options: [], range: videoRange)
            if repairedVideoIdCount > 0 {
                migrated = emptyVideoRegex.stringByReplacingMatches(
                    in: migrated,
                    options: [],
                    range: videoRange,
                    withTemplate: "$1videoId: placeholder-video-id"
                )
            }
        }

        return MigrationResult(
            content: migrated,
            legacyTypeChanges: legacyHits,
            repairedEmptyVideoIdCount: repairedVideoIdCount
        )
    }
}

/// Extracts the YAML frontmatter from a `.mdx` file, decodes the known
/// fields (including the typed `blocks:` list) and returns the remaining
/// markdown body as a string.
///
/// The on-disk YAML uses `gray-matter` on the JS side, so we only need to
/// support a small, predictable subset:
///
///   * scalar strings (quoted, single-quoted, or bare)
///   * boolean & integer scalars
///   * `- item` sequences
///   * nested mappings (one or two levels deep inside block entries)
///   * inline flow sequences `[a, b]`
///
/// Anything we cannot decode is surfaced as an `MDXParseError` with a line
/// reference so the user can open the file and fix by hand if needed.
enum MDXParser {
    enum ParseError: LocalizedError {
        case noFrontmatter(fileName: String)
        case invalidYAML(fileName: String, reason: String)
        case invalidBlock(fileName: String, reason: String)

        var errorDescription: String? {
            switch self {
            case .noFrontmatter(let file):
                "\(file) has no --- frontmatter block."
            case .invalidYAML(let file, let reason):
                "\(file): \(reason)"
            case .invalidBlock(let file, let reason):
                "\(file): \(reason)"
            }
        }
    }

    static func parse(_ raw: String, fileName: String) throws -> ProjectDocument {
        let (yamlBlock, body) = try splitFrontmatter(raw, fileName: fileName)
        let yaml = try YAMLDecoder.decode(yamlBlock, fileName: fileName)
        var front = try buildFrontmatter(from: yaml, fileName: fileName)
        synthesiseLayoutBlocksIfNeeded(&front)
        syncTopLevelFromLayoutBlocks(&front)
        return ProjectDocument(fileName: fileName, frontmatter: front, body: body)
    }

    private static func splitFrontmatter(_ raw: String, fileName: String) throws -> (yaml: String, body: String) {
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---" else {
            throw ParseError.noFrontmatter(fileName: fileName)
        }
        guard let closingIdx = lines.dropFirst().firstIndex(of: "---") else {
            throw ParseError.invalidYAML(fileName: fileName, reason: "Frontmatter block is unterminated.")
        }
        let yamlLines = Array(lines[1..<closingIdx])
        // body starts after the closing `---` line
        let bodyStart = closingIdx + 1
        let bodyLines = bodyStart < lines.count ? Array(lines[bodyStart...]) : []
        var body = bodyLines.joined(separator: "\n")
        while body.hasPrefix("\n") { body.removeFirst() }
        return (yamlLines.joined(separator: "\n"), body)
    }

    // MARK: - Frontmatter -> model

    private static func buildFrontmatter(from node: YAMLNode, fileName: String) throws -> ProjectFrontmatter {
        guard case .mapping(let map) = node else {
            throw ParseError.invalidYAML(fileName: fileName, reason: "Frontmatter must be a mapping.")
        }

        func string(_ key: String) -> String? { map[key]?.stringValue }
        func bool(_ key: String) -> Bool { map[key]?.boolValue ?? false }
        func array(_ key: String) -> [YAMLNode] { map[key]?.sequenceValue ?? [] }

        guard let title = string("title") else {
            throw ParseError.invalidYAML(fileName: fileName, reason: "Missing title.")
        }
        let slug = string("slug") ?? fileName.replacingOccurrences(of: ".mdx", with: "")
        let description = string("description") ?? ""
        let date = string("date") ?? ""
        let ownershipRaw = string("ownership") ?? "work"
        let ownership = ProjectFrontmatter.Ownership(rawValue: ownershipRaw) ?? .work
        var tags = array("tags").compactMap { $0.stringValue }
        // Legacy category migration path: preserve prior single category as a tag.
        if let legacyCategory = string("category"), !legacyCategory.isEmpty, !tags.contains(legacyCategory) {
            tags.append(legacyCategory)
        }

        var hero: ProjectFrontmatter.Hero?
        if case .mapping(let h) = map["hero"] ?? .null {
            hero = ProjectFrontmatter.Hero(
                eyebrow: h["eyebrow"]?.stringValue,
                title: h["title"]?.stringValue,
                subtitle: h["subtitle"]?.stringValue
            )
            if hero?.isEmpty == true { hero = nil }
        }

        var videoMeta: ProjectFrontmatter.VideoMeta?
        if case .mapping(let vm) = map["videoMeta"] ?? .null {
            let parsed = ProjectFrontmatter.VideoMeta(
                runtime: vm["runtime"]?.stringValue,
                platform: vm["platform"]?.stringValue,
                transcriptUrl: vm["transcriptUrl"]?.stringValue,
                credits: (vm["credits"]?.sequenceValue ?? []).compactMap { $0.stringValue }
            )
            videoMeta = parsed.isEmpty ? nil : parsed
        }

        let blocks: [ProjectBlock]
        if case .sequence(let seq) = map["blocks"] ?? .null {
            blocks = try seq.enumerated().compactMap { idx, node in
                try parseBlockIfPresent(node, index: idx, fileName: fileName)
            }
        } else {
            blocks = []
        }

        let headerImage = string("headerImage")

        return ProjectFrontmatter(
            title: title,
            slug: slug,
            description: description,
            date: date,
            ownership: ownership,
            tags: tags,
            thumbnail: string("thumbnail"),
            headerImage: headerImage,
            externalUrl: string("externalUrl"),
            featured: bool("featured"),
            draft: bool("draft"),
            role: string("role"),
            duration: string("duration"),
            impact: string("impact"),
            challenge: string("challenge"),
            approach: string("approach"),
            outcome: string("outcome"),
            videoMeta: videoMeta,
            hero: hero,
            blocks: blocks
        )
    }

    /// When the MDX has no `blocks:` (or no layout blocks), build the default order so legacy
    /// top-level frontmatter and content blocks match the pre-layout-block page.
    private static func synthesiseLayoutBlocksIfNeeded(_ front: inout ProjectFrontmatter) {
        let hasLayout = front.blocks.contains { $0.isLayoutBlock }
        if hasLayout {
            return
        }

        var out: [ProjectBlock] = []
        if let hero = front.hero, !hero.isEmpty {
            out.append(.pageHero(PageHeroBlock(eyebrow: hero.eyebrow, title: hero.title, subtitle: hero.subtitle)))
        }
        if let hi = front.headerImage, !hi.isEmpty {
            out.append(.headerImage(HeaderImageBlock(src: hi, alt: nil)))
        }
        out.append(.body(BodyBlock()))
        out.append(contentsOf: front.blocks)
        if caseStudySourcePresent(front) {
            out.append(.caseStudy(CaseStudyBlock(
                challenge: front.challenge,
                approach: front.approach,
                outcome: front.outcome,
                role: front.role,
                duration: front.duration
            )))
        }
        if let vm = front.videoMeta, !vm.isEmpty {
            out.append(.videoDetails(VideoDetailsBlock(
                runtime: vm.runtime,
                platform: vm.platform,
                transcriptUrl: vm.transcriptUrl,
                credits: vm.credits
            )))
        }
        if let ext = front.externalUrl, !ext.isEmpty {
            out.append(.externalLink(ExternalLinkBlock(href: ext, label: nil)))
        }
        out.append(.tagList(TagListBlock()))
        out.append(.relatedProjects(RelatedProjectsBlock()))
        front.blocks = out
    }

    /// When a layout block exists, `MDXSerialiser` omits the same data from the
    /// top-level YAML (the block is canonical). After parsing, mirror the block
    /// onto the top-level `ProjectFrontmatter` fields so in-memory state matches
    /// a re-parse of our serialised output.
    private static func syncTopLevelFromLayoutBlocks(_ front: inout ProjectFrontmatter) {
        for block in front.blocks {
            switch block {
            case .caseStudy(let b):
                front.challenge = b.challenge
                front.approach = b.approach
                front.outcome = b.outcome
                front.role = b.role
                front.duration = b.duration
            case .videoDetails(let b):
                let meta = ProjectFrontmatter.VideoMeta(
                    runtime: b.runtime,
                    platform: b.platform,
                    transcriptUrl: b.transcriptUrl,
                    credits: b.credits
                )
                front.videoMeta = meta.isEmpty ? nil : meta
            case .pageHero(let b):
                let h = ProjectFrontmatter.Hero(
                    eyebrow: b.eyebrow,
                    title: b.title,
                    subtitle: b.subtitle
                )
                front.hero = h.isEmpty ? nil : h
            case .headerImage(let b):
                if !b.src.isEmpty { front.headerImage = b.src }
            default:
                break
            }
        }
    }

    private static func caseStudySourcePresent(_ front: ProjectFrontmatter) -> Bool {
        let fields = [front.challenge, front.approach, front.outcome, front.role, front.duration]
        return fields.contains { ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    private static func parseBlockIfPresent(_ node: YAMLNode, index: Int, fileName: String) throws -> ProjectBlock? {
        guard case .mapping(let map) = node else {
            throw ParseError.invalidBlock(fileName: fileName, reason: "Block #\(index + 1) is not a mapping.")
        }
        guard let rawType = map["type"]?.stringValue else {
            throw ParseError.invalidBlock(fileName: fileName, reason: "Block #\(index + 1) missing type.")
        }
        let type = LegacyBlockMigration.parserCanonicalType(for: rawType)
        if type == "narrative" {
            return nil
        }
        return try parseBlock(node, index: index, fileName: fileName, knownType: type)
    }

    private static func parseBlock(_ node: YAMLNode, index: Int, fileName: String, knownType: String) throws -> ProjectBlock {
        guard case .mapping(let map) = node else {
            throw ParseError.invalidBlock(fileName: fileName, reason: "Block #\(index + 1) is not a mapping.")
        }
        let type = knownType

        switch type {
        case "projectSnapshot":
            let statusRaw = map["status"]?.stringValue ?? "planned"
            let status = ProjectSnapshotBlock.Status(rawValue: statusRaw) ?? .planned
            return .projectSnapshot(ProjectSnapshotBlock(
                projectTitle: map["projectTitle"]?.stringValue ?? "",
                summary: map["summary"]?.stringValue ?? "",
                status: status,
                ownerTeam: map["ownerTeam"]?.stringValue ?? "",
                timelineStart: map["timelineStart"]?.stringValue ?? "",
                timelineTargetCompletion: map["timelineTargetCompletion"]?.stringValue ?? "",
                budgetHeadline: map["budgetHeadline"]?.stringValue
            ))

        case "keyStats":
            let items = (map["items"]?.sequenceValue ?? []).compactMap { node -> KeyStatsBlock.Item? in
                guard case .mapping(let m) = node else { return nil }
                return KeyStatsBlock.Item(
                    label: m["label"]?.stringValue ?? "",
                    value: m["value"]?.stringValue ?? "",
                    unit: m["unit"]?.stringValue,
                    context: m["context"]?.stringValue,
                    lastUpdated: m["lastUpdated"]?.stringValue ?? ""
                )
            }
            return .keyStats(KeyStatsBlock(
                title: map["title"]?.stringValue ?? "Key stats",
                items: items
            ))

        case "goalsMetrics":
            let items = (map["items"]?.sequenceValue ?? []).compactMap { node -> GoalsMetricsBlock.Item? in
                guard case .mapping(let m) = node else { return nil }
                return GoalsMetricsBlock.Item(
                    goal: m["goal"]?.stringValue ?? "",
                    successMeasure: m["successMeasure"]?.stringValue ?? "",
                    baseline: m["baseline"]?.stringValue ?? "",
                    target: m["target"]?.stringValue ?? "",
                    reportingCadence: m["reportingCadence"]?.stringValue ?? ""
                )
            }
            return .goalsMetrics(GoalsMetricsBlock(
                title: map["title"]?.stringValue ?? "Goals & success metrics",
                items: items
            ))

        case "body":
            return .body(BodyBlock())

        case "pageHero":
            return .pageHero(PageHeroBlock(
                eyebrow: map["eyebrow"]?.stringValue,
                title: map["title"]?.stringValue,
                subtitle: map["subtitle"]?.stringValue
            ))

        case "headerImage":
            return .headerImage(HeaderImageBlock(
                src: map["src"]?.stringValue ?? "",
                alt: map["alt"]?.stringValue
            ))

        case "preface":
            return .preface(PrefaceBlock(text: map["text"]?.stringValue ?? ""))

        case "caseStudy":
            return .caseStudy(CaseStudyBlock(
                challenge: map["challenge"]?.stringValue,
                approach: map["approach"]?.stringValue,
                outcome: map["outcome"]?.stringValue,
                role: map["role"]?.stringValue,
                duration: map["duration"]?.stringValue
            ))

        case "videoDetails":
            let credits = (map["credits"]?.sequenceValue ?? []).compactMap { $0.stringValue }
            return .videoDetails(VideoDetailsBlock(
                runtime: map["runtime"]?.stringValue,
                platform: map["platform"]?.stringValue,
                transcriptUrl: map["transcriptUrl"]?.stringValue,
                credits: credits
            ))

        case "externalLink":
            return .externalLink(ExternalLinkBlock(
                href: map["href"]?.stringValue ?? "",
                label: map["label"]?.stringValue
            ))

        case "tagList":
            return .tagList(TagListBlock())

        case "relatedProjects":
            return .relatedProjects(RelatedProjectsBlock())

        case "quote":
            return .quote(QuoteBlock(
                quote: map["quote"]?.stringValue ?? "",
                attributionName: map["attributionName"]?.stringValue,
                attributionRoleContext: map["attributionRoleContext"]?.stringValue,
                theme: map["theme"]?.stringValue
            ))

        case "statCards":
            // Legacy alias retained for existing content. Normalises to keyStats.
            let items = (map["items"]?.sequenceValue ?? []).compactMap { node -> KeyStatsBlock.Item? in
                guard case .mapping(let m) = node else { return nil }
                return KeyStatsBlock.Item(
                    label: m["label"]?.stringValue ?? "",
                    value: m["value"]?.stringValue ?? "",
                    unit: nil,
                    context: m["detail"]?.stringValue,
                    lastUpdated: ""
                )
            }
            return .keyStats(KeyStatsBlock(
                title: map["title"]?.stringValue ?? "Key stats",
                items: items
            ))

        case "mediaGallery", "mediaGrid":
            let items = (map["items"]?.sequenceValue ?? []).compactMap { node -> MediaGalleryBlock.Item? in
                guard case .mapping(let m) = node else { return nil }
                return MediaGalleryBlock.Item(
                    src: m["src"]?.stringValue ?? "",
                    alt: m["alt"]?.stringValue ?? "",
                    caption: m["caption"]?.stringValue,
                    credit: m["credit"]?.stringValue,
                    date: m["date"]?.stringValue,
                    location: m["location"]?.stringValue
                )
            }
            return .mediaGallery(MediaGalleryBlock(
                title: map["title"]?.stringValue ?? "Media gallery",
                items: items
            ))

        case "videoShowcase":
            let variantRaw = map["variant"]?.stringValue ?? "cinema"
            let variant = VideoShowcaseBlock.Variant(rawValue: variantRaw) ?? .cinema
            let highlights = (map["highlights"]?.sequenceValue ?? []).compactMap { $0.stringValue }
            let source: VideoShowcaseBlock.Source
            if case .mapping(let src) = map["source"] ?? .null {
                if src["kind"]?.stringValue == "youtube" {
                    source = .youtube(
                        videoId: src["videoId"]?.stringValue ?? ""
                    )
                } else if src["kind"]?.stringValue == "vimeo" {
                    source = .vimeo(
                        videoId: src["videoId"]?.stringValue ?? ""
                    )
                } else {
                    let captions: [VideoShowcaseBlock.CaptionTrack] = (src["captions"]?.sequenceValue ?? []).compactMap { captionNode in
                        guard case .mapping(let c) = captionNode else { return nil }
                        return VideoShowcaseBlock.CaptionTrack(
                            src: c["src"]?.stringValue ?? "",
                            srclang: c["srclang"]?.stringValue ?? "",
                            label: c["label"]?.stringValue ?? "",
                            isDefault: c["default"]?.boolValue ?? false
                        )
                    }
                    source = .file(
                        src: src["src"]?.stringValue ?? "",
                        poster: src["poster"]?.stringValue,
                        mimeType: src["mimeType"]?.stringValue,
                        fallbackUrl: src["fallbackUrl"]?.stringValue,
                        captions: captions
                    )
                }
            } else {
                source = .youtube(videoId: "")
            }
            return .videoShowcase(VideoShowcaseBlock(
                variant: variant,
                title: map["title"]?.stringValue ?? "",
                description: map["description"]?.stringValue,
                highlights: highlights,
                source: source,
                ctaText: map["ctaText"]?.stringValue,
                ctaHref: map["ctaHref"]?.stringValue
            ))

        case "cta":
            let links = (map["links"]?.sequenceValue ?? []).compactMap { node -> CTABlock.Link? in
                guard case .mapping(let m) = node else { return nil }
                return CTABlock.Link(
                    label: m["label"]?.stringValue ?? "",
                    href: m["href"]?.stringValue ?? ""
                )
            }
            return .cta(CTABlock(
                title: map["title"]?.stringValue ?? "",
                description: map["description"]?.stringValue,
                links: links
            ))

        default:
            throw ParseError.invalidBlock(
                fileName: fileName,
                reason: "Block #\(index + 1) has unknown type '\(type)'."
            )
        }
    }
}
