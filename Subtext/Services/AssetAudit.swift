import AppKit
import Foundation

/// Read-only site health audit: enumerate `/public/images/**`, collect every
/// asset reference in splash + projects, and diff them to surface orphans +
/// broken links. Also runs a pragmatic SEO checklist over each project.
///
/// The service is an actor because directory enumeration and file stat calls
/// are slow enough to block the UI on repos with hundreds of images.
actor AssetAudit {

    // MARK: - Enumeration

    struct AssetEntry: Identifiable, Sendable, Equatable {
        /// Website-relative path (e.g. `/images/hero.png`) — what lives in
        /// `splash.json` and MDX and what Subtext writes back.
        var relativePath: String
        var url: URL
        var sizeBytes: Int64
        var pixelSize: CGSize?
        var modified: Date

        var id: String { relativePath }
        var fileName: String { url.lastPathComponent }

        var isImage: Bool {
            let ext = url.pathExtension.lowercased()
            return ["png", "jpg", "jpeg", "gif", "webp", "heic", "avif", "svg"].contains(ext)
        }
    }

    /// Recursively walks `/public/images`, returning every regular file.
    /// Scoped to `/images` (rather than all of `/public`) so infra files —
    /// `favicon.ico`, `robots.txt`, fonts — don't show up as orphans.
    /// Silently skips dotfiles and unreadable entries.
    func enumerateAssets() -> [AssetEntry] {
        let publicRoot = RepoConstants.publicDirectory
        let root = publicRoot.appending(path: "images", directoryHint: .isDirectory)
        let publicPath = publicRoot.path(percentEncoded: false)
        let fm = FileManager.default

        guard fm.fileExists(atPath: root.path(percentEncoded: false)) else { return [] }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [AssetEntry] = []
        for case let url as URL in enumerator {
            guard
                let values = try? url.resourceValues(forKeys: Set(keys)),
                values.isRegularFile == true
            else { continue }

            let absolute = url.path(percentEncoded: false)
            guard absolute.hasPrefix(publicPath) else { continue }
            var relative = String(absolute.dropFirst(publicPath.count))
            if !relative.hasPrefix("/") { relative = "/" + relative }

            let size = Int64(values.fileSize ?? 0)
            let modified = values.contentModificationDate ?? Date(timeIntervalSince1970: 0)

            let pixelSize = Self.readPixelSize(at: url)

            results.append(AssetEntry(
                relativePath: relative,
                url: url,
                sizeBytes: size,
                pixelSize: pixelSize,
                modified: modified
            ))
        }

        return results.sorted { $0.relativePath < $1.relativePath }
    }

    /// Uses CoreGraphics to read just the image header — cheap, works for
    /// every format `NSImage` understands. Returns `nil` for non-images.
    private static func readPixelSize(at url: URL) -> CGSize? {
        let ext = url.pathExtension.lowercased()
        guard !["mp4", "mov", "webm", "pdf"].contains(ext) else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        let w = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
        let h = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
        guard w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    // MARK: - Reference extraction

    /// Every website-relative asset path referenced from splash or projects.
    /// Paths are normalised to start with `/` for comparison against
    /// `enumerateAssets()` output.
    func referencedAssetPaths(splash: SplashContent, projects: [ProjectDocument]) -> Set<String> {
        var paths: Set<String> = []

        for section in splash.sections {
            collectPaths(from: section.visual, into: &paths)
        }

        for project in projects {
            if let thumb = project.frontmatter.thumbnail {
                addIfAsset(thumb, into: &paths)
            }
            for block in project.frontmatter.blocks {
                collectPaths(from: block, into: &paths)
            }
            // MDX body: ![alt](/images/x.png) and src="/images/x.png"
            for match in Self.markdownImagePattern.matches(
                in: project.body,
                range: NSRange(project.body.startIndex..., in: project.body)
            ) {
                if match.numberOfRanges > 1,
                   let r = Range(match.range(at: 1), in: project.body) {
                    addIfAsset(String(project.body[r]), into: &paths)
                }
            }
            for match in Self.srcAttrPattern.matches(
                in: project.body,
                range: NSRange(project.body.startIndex..., in: project.body)
            ) {
                if match.numberOfRanges > 1,
                   let r = Range(match.range(at: 1), in: project.body) {
                    addIfAsset(String(project.body[r]), into: &paths)
                }
            }
        }

        return paths
    }

    private nonisolated static let markdownImagePattern: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)\s]+)"#)
    }()

    private nonisolated static let srcAttrPattern: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"src=['\"]([^'\"]+)['\"]"#)
    }()

    private func addIfAsset(_ raw: String, into set: inout Set<String>) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.hasPrefix("http") { return }
        let normalised = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        set.insert(normalised)
    }

    private func collectPaths(from visual: VisualContent, into set: inout Set<String>) {
        switch visual {
        case .photo(let p):
            addIfAsset(p.src, into: &set)
        case .ticket, .speech, .scramble, .terminal:
            break
        }
    }

    private func collectPaths(from block: ProjectBlock, into set: inout Set<String>) {
        switch block {
        case .mediaGallery(let m):
            for item in m.items { addIfAsset(item.src, into: &set) }
        case .videoShowcase(let v):
            switch v.source {
            case .youtube, .vimeo:
                break
            case .file(let src, let poster, _, let fallbackUrl, let captions):
                addIfAsset(src, into: &set)
                if let poster { addIfAsset(poster, into: &set) }
                if let fallbackUrl { addIfAsset(fallbackUrl, into: &set) }
                for caption in captions {
                    addIfAsset(caption.src, into: &set)
                }
            }
        case .narrative, .quote, .cta, .projectSnapshot, .keyStats, .goalsMetrics:
            break
        }
    }

    // MARK: - SEO lint

    struct SEOIssue: Sendable, Equatable, Identifiable {
        enum Severity: Sendable { case warning, error }
        var id: String { "\(fileName).\(code)" }
        var fileName: String
        var code: String
        var message: String
        var severity: Severity
    }

    /// A condensed lint inspired by the plan: fields that obviously hurt the
    /// site when wrong (title length, missing excerpt, missing cover, dud
    /// slug, missing date). Never fatal — just surfaced as amber pills.
    func seoIssues(for projects: [ProjectDocument]) -> [String: [SEOIssue]] {
        var out: [String: [SEOIssue]] = [:]
        for project in projects {
            let fm = project.frontmatter
            var issues: [SEOIssue] = []

            if fm.title.isEmpty {
                issues.append(.init(fileName: project.fileName, code: "title-missing",
                                    message: "Title is empty.", severity: .error))
            } else if fm.title.count < 10 {
                issues.append(.init(fileName: project.fileName, code: "title-short",
                                    message: "Title is under 10 characters — reads short on listings.",
                                    severity: .warning))
            } else if fm.title.count > 70 {
                issues.append(.init(fileName: project.fileName, code: "title-long",
                                    message: "Title is over 70 characters — may truncate in search results.",
                                    severity: .warning))
            }

            if fm.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(fileName: project.fileName, code: "description-missing",
                                    message: "Description / excerpt is empty.", severity: .error))
            } else if fm.description.count < 40 {
                issues.append(.init(fileName: project.fileName, code: "description-short",
                                    message: "Description under 40 characters — add more context.",
                                    severity: .warning))
            }

            if (fm.thumbnail ?? "").isEmpty {
                issues.append(.init(fileName: project.fileName, code: "thumbnail-missing",
                                    message: "No thumbnail set.", severity: .warning))
            }

            if fm.date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(fileName: project.fileName, code: "date-missing",
                                    message: "Date is empty.", severity: .error))
            } else if ISO8601Date.parse(fm.date) == nil {
                issues.append(.init(fileName: project.fileName, code: "date-invalid",
                                    message: "Date “\(fm.date)” is not YYYY-MM-DD.", severity: .error))
            }

            let expectedFile = fm.slug + ".mdx"
            if !fm.slug.isEmpty, project.fileName != expectedFile {
                issues.append(.init(fileName: project.fileName, code: "slug-mismatch",
                                    message: "Slug “\(fm.slug)” doesn't match filename “\(project.fileName)”.",
                                    severity: .warning))
            }

            if !issues.isEmpty {
                out[project.fileName] = issues
            }
        }
        return out
    }

    // MARK: - Combined audit

    struct AuditReport: Sendable, Equatable {
        var assets: [AssetEntry]
        var orphans: [AssetEntry]
        var broken: [String]
        var seoIssues: [String: [SEOIssue]]

        var totalBytes: Int64 { assets.reduce(0) { $0 + $1.sizeBytes } }
        var orphanBytes: Int64 { orphans.reduce(0) { $0 + $1.sizeBytes } }
    }

    /// One-shot audit combining enumeration, reference scan, and SEO lint.
    /// The diff is purely set-based: orphan = on disk but not referenced,
    /// broken = referenced but not on disk.
    func audit(splash: SplashContent, projects: [ProjectDocument]) -> AuditReport {
        let assets = enumerateAssets()
        let referenced = referencedAssetPaths(splash: splash, projects: projects)

        let knownPaths = Set(assets.map { $0.relativePath })
        let orphans = assets
            .filter { $0.isImage && !referenced.contains($0.relativePath) }
        // Only /images/** paths are our responsibility; ignore /favicon.ico
        // and friends referenced from elsewhere.
        let broken = referenced
            .filter { $0.hasPrefix("/images/") && !knownPaths.contains($0) }
            .sorted()

        let seo = seoIssues(for: projects)

        return AuditReport(
            assets: assets,
            orphans: orphans,
            broken: broken,
            seoIssues: seo
        )
    }
}

// MARK: - Inline SEO helper

/// Sync, nonisolated mirror of `AssetAudit.seoIssues` used by list rows so
/// they don't spin up an actor hop to paint a badge. Messages are kept in
/// lockstep with the full audit; don't let them drift.
enum SEOPreview {
    static func issues(for project: ProjectDocument) -> [String] {
        let fm = project.frontmatter
        var messages: [String] = []

        if fm.title.isEmpty {
            messages.append("Title is empty.")
        } else if fm.title.count < 10 {
            messages.append("Title under 10 chars.")
        } else if fm.title.count > 70 {
            messages.append("Title over 70 chars.")
        }

        if fm.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Description is empty.")
        } else if fm.description.count < 40 {
            messages.append("Description under 40 chars.")
        }

        if (fm.thumbnail ?? "").isEmpty {
            messages.append("No thumbnail.")
        }

        let date = fm.date.trimmingCharacters(in: .whitespacesAndNewlines)
        if date.isEmpty {
            messages.append("Date is empty.")
        } else if ISO8601Date.parse(date) == nil {
            messages.append("Date “\(fm.date)” isn't YYYY-MM-DD.")
        }

        let expected = fm.slug + ".mdx"
        if !fm.slug.isEmpty, project.fileName != expected {
            messages.append("Slug doesn't match filename.")
        }

        return messages
    }
}

// MARK: - Formatting helpers

enum ByteFormatter {
    static func string(for bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB]
        return f.string(fromByteCount: bytes)
    }
}
