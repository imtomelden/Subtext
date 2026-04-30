import Foundation

/// All file I/O for the CMS. Actor-isolated so concurrent reads/writes never
/// overlap.
actor FileService {
    private struct CachedProject {
        let modificationDate: Date
        let document: ProjectDocument
    }

    private var projectCache: [URL: CachedProject] = [:]

    enum FileError: LocalizedError {
        case fileMissing(URL)
        case decodingFailed(URL, String)
        case encodingFailed(URL, String)
        case writeFailed(URL, String)
        case schemaMismatch(URL, String)

        var errorDescription: String? {
            switch self {
            case .fileMissing(let url):
                "Missing file: \(url.lastPathComponent)"
            case .decodingFailed(let url, let reason):
                "Could not decode \(url.lastPathComponent): \(reason)"
            case .encodingFailed(let url, let reason):
                "Could not encode \(url.lastPathComponent): \(reason)"
            case .writeFailed(let url, let reason):
                "Failed to write \(url.lastPathComponent): \(reason)"
            case .schemaMismatch(let url, let reason):
                "Refusing to save \(url.lastPathComponent): \(reason)"
            }
        }
    }

    // MARK: - Splash

    func readSplash() throws -> SplashContent {
        let url = RepoConstants.splashFile
        let data = try readData(at: url)
        do {
            return try JSONDecoder().decode(SplashContent.self, from: data)
        } catch {
            throw FileError.decodingFailed(url, "\(error)")
        }
    }

    func writeSplash(_ content: SplashContent) throws {
        let url = RepoConstants.splashFile
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Website writes with indent=1 via Node's JSON.stringify; match that
        // format so diffs stay small even when edits originate here.
        let pretty = try compactIndent(encoder: encoder, value: content)
        try validateJSONRoundTrip(pretty, original: content, url: url)
        try atomicWrite(pretty, to: url)
    }

    /// Encode with JSONEncoder, then re-indent with 1-space indent to match the
    /// existing file style on disk.
    private func compactIndent<T: Encodable>(encoder: JSONEncoder, value: T) throws -> Data {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw FileError.encodingFailed(RepoConstants.splashFile, "\(error)")
        }
        guard let pretty = String(data: data, encoding: .utf8) else { return data }
        // Replace 2-space indent with 1-space indent (the website format).
        var reindented = ""
        reindented.reserveCapacity(pretty.count)
        for line in pretty.split(separator: "\n", omittingEmptySubsequences: false) {
            var leadingSpaces = 0
            for c in line {
                if c == " " { leadingSpaces += 1 } else { break }
            }
            let halfIndent = String(repeating: " ", count: leadingSpaces / 2)
            let rest = line.dropFirst(leadingSpaces)
            reindented += halfIndent + rest + "\n"
        }
        if !reindented.hasSuffix("\n") { reindented += "\n" }
        return Data(reindented.utf8)
    }

    // MARK: - Site

    func readSite() throws -> SiteSettings {
        let url = RepoConstants.siteFile
        let data = try readData(at: url)
        do {
            return try JSONDecoder().decode(SiteSettings.self, from: data)
        } catch {
            throw FileError.decodingFailed(url, "\(error)")
        }
    }

    func writeSite(_ settings: SiteSettings) throws {
        let url = RepoConstants.siteFile
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(settings)
            let string = (String(data: data, encoding: .utf8) ?? "") + "\n"
            let payload = Data(string.utf8)
            try validateJSONRoundTrip(payload, original: settings, url: url)
            try atomicWrite(payload, to: url)
        } catch let error as FileError {
            throw error
        } catch {
            throw FileError.encodingFailed(url, "\(error)")
        }
    }

    // MARK: - Projects

    func readAllProjects() throws -> [ProjectDocument] {
        let dir = RepoConstants.projectsDirectory
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try contents
            .filter { $0.pathExtension.lowercased() == "mdx" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try readProject(at: $0) }
    }

    func readProject(at url: URL) throws -> ProjectDocument {
        let knownModificationDate = fileModificationDate(at: url)
        if let cached = projectCache[url],
           abs(cached.modificationDate.timeIntervalSince(knownModificationDate)) <= 1 {
            return cached.document
        }

        let raw = try readString(at: url)
        var doc = try MDXParser.parse(raw, fileName: url.lastPathComponent)
        var needsRewrite = false

        if frontmatterKey("slug", existsIn: raw) == false {
            // Legacy project files may predate required `slug`; normalise and
            // persist once on read so Astro schema validation doesn't fail later.
            let fileSlug = url.deletingPathExtension().lastPathComponent
            doc.frontmatter.slug = fileSlug
            needsRewrite = true
        }

        if frontmatterKey("ownership", existsIn: raw) == false {
            // Ensure legacy files gain explicit ownership so taxonomy is stable.
            doc.frontmatter.ownership = .work
            needsRewrite = true
        }

        // NOTE: We deliberately do NOT touch `frontmatter.draft` here. The
        // Astro site treats `draft: true` as "do not publish", so silently
        // clearing it on read would publish content the author intended to
        // keep private. Toggling draft is now an explicit user action via
        // the project editor's Publish/Unpublish toggle.

        if needsRewrite {
            try atomicWrite(Data(MDXSerialiser.serialise(doc).utf8), to: url)
        }

        let updatedModificationDate = needsRewrite ? fileModificationDate(at: url) : knownModificationDate
        projectCache[url] = CachedProject(modificationDate: updatedModificationDate, document: doc)
        return doc
    }

    func writeProject(_ document: ProjectDocument, to url: URL) throws {
        let text = MDXSerialiser.serialise(document)
        try validateMDXRoundTrip(text, original: document, url: url)
        try atomicWrite(Data(text.utf8), to: url)
        projectCache[url] = CachedProject(modificationDate: fileModificationDate(at: url), document: document)
    }

    func deleteProject(at url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path(percentEncoded: false)) {
            try fm.removeItem(at: url)
        }
        projectCache.removeValue(forKey: url)
    }

    // MARK: - Schema validation

    /// Decode-then-encode the encoded payload and verify the round-trip is
    /// byte-identical. Catches the class of bugs where a Codable
    /// implementation silently drops or renames fields — the most common
    /// cause of "edits don't reach the site" regressions.
    private func validateJSONRoundTrip<T: Codable & Equatable>(
        _ payload: Data,
        original: T,
        url: URL
    ) throws {
        do {
            let decoded = try JSONDecoder().decode(T.self, from: payload)
            guard decoded == original else {
                throw FileError.schemaMismatch(url, "round-trip differs — a field was dropped or renamed.")
            }
        } catch let error as FileError {
            throw error
        } catch {
            throw FileError.schemaMismatch(url, "\(error)")
        }
    }

    /// MDX equivalent: parse the freshly serialised text and compare to the
    /// document that produced it. Only frontmatter + body are checked; whitespace
    /// differences outside content are benign so we ignore them.
    private func validateMDXRoundTrip(
        _ text: String,
        original: ProjectDocument,
        url: URL
    ) throws {
        do {
            let reparsed = try MDXParser.parse(text, fileName: url.lastPathComponent)
            let lhs = canonicalFrontmatter(reparsed.frontmatter)
            let rhs = canonicalFrontmatter(original.frontmatter)
            // Compare frontmatter exactly — every field must round-trip —
            // and bodies after trimming trailing whitespace, because the
            // serialiser always normalises to a single trailing newline.
            guard lhs == rhs else {
                let detail = firstFrontmatterDifference(lhs: lhs, rhs: rhs) ?? "a field was dropped or renamed"
                throw FileError.schemaMismatch(url, "frontmatter round-trip differs — \(detail).")
            }
            let trimmedA = reparsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedB = original.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedA == trimmedB else {
                throw FileError.schemaMismatch(url, "body round-trip differs — escaping or serialisation changed content.")
            }
        } catch let error as FileError {
            throw error
        } catch {
            throw FileError.schemaMismatch(url, "\(error)")
        }
    }

    // MARK: - Helpers

    private func readData(at url: URL) throws -> Data {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw FileError.fileMissing(url)
        }
        return try Data(contentsOf: url)
    }

    private func readString(at url: URL) throws -> String {
        let data = try readData(at: url)
        return String(decoding: data, as: UTF8.self)
    }

    /// Write via a temp file + atomic rename so a partially written file is
    /// never visible to the Astro watcher.
    private func atomicWrite(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let tmp = parent.appending(path: "\(url.lastPathComponent).tmp-\(Int(Date().timeIntervalSince1970))", directoryHint: .notDirectory)
        do {
            try data.write(to: tmp, options: .atomic)
            if fm.fileExists(atPath: url.path(percentEncoded: false)) {
                _ = try fm.replaceItemAt(url, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: url)
            }
        } catch {
            try? fm.removeItem(at: tmp)
            throw FileError.writeFailed(url, "\(error)")
        }
    }

    private func frontmatterKey(_ key: String, existsIn raw: String) -> Bool {
        guard let range = raw.range(of: #"(?m)^---\s*$[\s\S]*?(?m)^---\s*$"#, options: .regularExpression) else {
            return false
        }
        let frontmatter = String(raw[range])
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let pattern = #"(?m)^\#(escaped)\s*:"# 
        return frontmatter.range(of: pattern, options: .regularExpression) != nil
    }

    private func fileModificationDate(at url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func canonicalFrontmatter(_ front: ProjectFrontmatter) -> ProjectFrontmatter {
        var out = front
        out.thumbnail = normaliseOptionalString(out.thumbnail)
        out.headerImage = normaliseOptionalString(out.headerImage)
        out.externalUrl = normaliseOptionalString(out.externalUrl)
        out.role = normaliseOptionalString(out.role)
        out.duration = normaliseOptionalString(out.duration)
        out.impact = normaliseOptionalString(out.impact)
        out.challenge = normaliseOptionalString(out.challenge)
        out.approach = normaliseOptionalString(out.approach)
        out.outcome = normaliseOptionalString(out.outcome)

        if var hero = out.hero {
            hero.eyebrow = normaliseOptionalString(hero.eyebrow)
            hero.title = normaliseOptionalString(hero.title)
            hero.subtitle = normaliseOptionalString(hero.subtitle)
            out.hero = hero.isEmpty ? nil : hero
        }

        if var videoMeta = out.videoMeta {
            videoMeta.runtime = normaliseOptionalString(videoMeta.runtime)
            videoMeta.platform = normaliseOptionalString(videoMeta.platform)
            videoMeta.transcriptUrl = normaliseOptionalString(videoMeta.transcriptUrl)
            out.videoMeta = videoMeta.isEmpty ? nil : videoMeta
        }

        out.blocks = out.blocks.map { canonicalBlock($0) }
        syncDerivedTopLevelFieldsFromLayoutBlocks(&out)
        return out
    }

    private func canonicalBlock(_ block: ProjectBlock) -> ProjectBlock {
        switch block {
        case .pageHero(var b):
            b.eyebrow = normaliseOptionalString(b.eyebrow)
            b.title = normaliseOptionalString(b.title)
            b.subtitle = normaliseOptionalString(b.subtitle)
            return .pageHero(b)
        case .headerImage(var b):
            b.alt = normaliseOptionalString(b.alt)
            return .headerImage(b)
        case .caseStudy(var b):
            b.challenge = normaliseOptionalString(b.challenge)
            b.approach = normaliseOptionalString(b.approach)
            b.outcome = normaliseOptionalString(b.outcome)
            b.role = normaliseOptionalString(b.role)
            b.duration = normaliseOptionalString(b.duration)
            return .caseStudy(b)
        case .videoDetails(var b):
            b.runtime = normaliseOptionalString(b.runtime)
            b.platform = normaliseOptionalString(b.platform)
            b.transcriptUrl = normaliseOptionalString(b.transcriptUrl)
            return .videoDetails(b)
        case .externalLink(var b):
            b.label = normaliseOptionalString(b.label)
            return .externalLink(b)
        case .quote(var b):
            b.attributionName = normaliseOptionalString(b.attributionName)
            b.attributionRoleContext = normaliseOptionalString(b.attributionRoleContext)
            b.theme = normaliseOptionalString(b.theme)
            return .quote(b)
        case .mediaGallery(var b):
            b.items = b.items.map { item in
                var out = item
                out.caption = normaliseOptionalString(out.caption)
                out.credit = normaliseOptionalString(out.credit)
                out.date = normaliseOptionalString(out.date)
                out.location = normaliseOptionalString(out.location)
                return out
            }
            return .mediaGallery(b)
        case .videoShowcase(var b):
            b.description = normaliseOptionalString(b.description)
            b.ctaText = normaliseOptionalString(b.ctaText)
            b.ctaHref = normaliseOptionalString(b.ctaHref)
            return .videoShowcase(b)
        case .cta(var b):
            b.description = normaliseOptionalString(b.description)
            return .cta(b)
        default:
            return block
        }
    }

    private func normaliseOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    /// Keep round-trip validation aligned with parser semantics: when a layout
    /// block exists, it is canonical and top-level mirrors should follow it.
    private func syncDerivedTopLevelFieldsFromLayoutBlocks(_ front: inout ProjectFrontmatter) {
        for block in front.blocks {
            switch block {
            case .caseStudy(let b):
                front.challenge = normaliseOptionalString(b.challenge)
                front.approach = normaliseOptionalString(b.approach)
                front.outcome = normaliseOptionalString(b.outcome)
                front.role = normaliseOptionalString(b.role)
                front.duration = normaliseOptionalString(b.duration)
            case .videoDetails(let b):
                let meta = ProjectFrontmatter.VideoMeta(
                    runtime: normaliseOptionalString(b.runtime),
                    platform: normaliseOptionalString(b.platform),
                    transcriptUrl: normaliseOptionalString(b.transcriptUrl),
                    credits: b.credits
                )
                front.videoMeta = meta.isEmpty ? nil : meta
            case .pageHero(let b):
                let hero = ProjectFrontmatter.Hero(
                    eyebrow: normaliseOptionalString(b.eyebrow),
                    title: normaliseOptionalString(b.title),
                    subtitle: normaliseOptionalString(b.subtitle)
                )
                front.hero = hero.isEmpty ? nil : hero
            case .headerImage(let b):
                front.headerImage = normaliseOptionalString(b.src)
            default:
                break
            }
        }
    }

    private func firstFrontmatterDifference(lhs: ProjectFrontmatter, rhs: ProjectFrontmatter) -> String? {
        if lhs.title != rhs.title { return "title changed" }
        if lhs.slug != rhs.slug { return "slug changed" }
        if lhs.description != rhs.description { return "description changed" }
        if lhs.date != rhs.date { return "date changed" }
        if lhs.ownership != rhs.ownership { return "ownership changed" }
        if lhs.tags != rhs.tags { return "tags changed" }
        if lhs.thumbnail != rhs.thumbnail { return "thumbnail changed" }
        if lhs.headerImage != rhs.headerImage { return "headerImage changed" }
        if lhs.externalUrl != rhs.externalUrl { return "externalUrl changed" }
        if lhs.featured != rhs.featured { return "featured changed" }
        if lhs.draft != rhs.draft { return "draft changed" }
        if lhs.role != rhs.role { return "role changed" }
        if lhs.duration != rhs.duration { return "duration changed" }
        if lhs.impact != rhs.impact { return "impact changed" }
        if lhs.challenge != rhs.challenge { return "challenge changed" }
        if lhs.approach != rhs.approach { return "approach changed" }
        if lhs.outcome != rhs.outcome { return "outcome changed" }
        if lhs.videoMeta != rhs.videoMeta { return "videoMeta changed" }
        if lhs.hero != rhs.hero { return "hero changed" }
        if lhs.blocks != rhs.blocks { return "blocks changed" }
        return nil
    }
}
