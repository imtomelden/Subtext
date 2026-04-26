import Foundation

/// All file I/O for the CMS. Actor-isolated so concurrent reads/writes never
/// overlap.
actor FileService {
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

        if doc.frontmatter.draft {
            // Drafts are no longer the default project state; normalise old
            // files to published so all project pages are treated consistently.
            doc.frontmatter.draft = false
            needsRewrite = true
        }

        if needsRewrite {
            try atomicWrite(Data(MDXSerialiser.serialise(doc).utf8), to: url)
        }
        return doc
    }

    func writeProject(_ document: ProjectDocument, to url: URL) throws {
        let text = MDXSerialiser.serialise(document)
        try validateMDXRoundTrip(text, original: document, url: url)
        try atomicWrite(Data(text.utf8), to: url)
    }

    func deleteProject(at url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path(percentEncoded: false)) {
            try fm.removeItem(at: url)
        }
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
            // Compare frontmatter exactly — every field must round-trip —
            // and bodies after trimming trailing whitespace, because the
            // serialiser always normalises to a single trailing newline.
            guard reparsed.frontmatter == original.frontmatter else {
                throw FileError.schemaMismatch(url, "frontmatter round-trip differs — a field was dropped or renamed.")
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
}
