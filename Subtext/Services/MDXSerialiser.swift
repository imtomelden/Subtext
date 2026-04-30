import Foundation

enum MDXSerialiser {
    static func serialise(_ doc: ProjectDocument) -> String {
        var out = "---\n"
        out += renderFrontmatter(doc.frontmatter)
        out += "---\n"
        let trimmed = doc.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return out }
        out += "\n" + trimmed + "\n"
        return out
    }

    private static func renderFrontmatter(_ f: ProjectFrontmatter) -> String {
        let kinds = Set(f.blocks.map(\.kind))
        let hasPageHero = kinds.contains(.pageHero)
        let hasHeaderImageBlock = kinds.contains(.headerImage)
        let hasCaseStudy = kinds.contains(.caseStudy)
        let hasVideoDetails = kinds.contains(.videoDetails)

        var lines: [String] = []
        lines.append(keyValue("title", quoted: f.title))
        lines.append(keyValue("slug", raw: f.slug))
        lines.append(keyValue("description", quoted: f.description))
        lines.append("date: \(yamlDateValue(f.date))")
        lines.append(keyValue("ownership", quoted: f.ownership.rawValue))
        if f.featured { lines.append("featured: true") }
        if !hasCaseStudy, let role = f.role { lines.append(keyValue("role", quoted: role)) }
        if !hasCaseStudy, let duration = f.duration { lines.append(keyValue("duration", quoted: duration)) }
        if let impact = f.impact { lines.append(keyValue("impact", quoted: impact)) }
        if !hasCaseStudy, let challenge = f.challenge { lines.append(keyValue("challenge", quoted: challenge)) }
        if !hasCaseStudy, let approach = f.approach { lines.append(keyValue("approach", quoted: approach)) }
        if !hasCaseStudy, let outcome = f.outcome { lines.append(keyValue("outcome", quoted: outcome)) }

        lines.append(f.tags.isEmpty ? "tags: []" : "tags:")
        for tag in f.tags { lines.append("  - \(yamlScalar(tag))") }

        if let thumbnail = f.thumbnail, !thumbnail.isEmpty { lines.append(keyValue("thumbnail", raw: thumbnail)) }
        if !hasHeaderImageBlock, let headerImage = f.headerImage, !headerImage.isEmpty { lines.append(keyValue("headerImage", raw: headerImage)) }
        if let ext = f.externalUrl, !ext.isEmpty { lines.append(keyValue("externalUrl", raw: ext)) }
        if f.draft { lines.append("draft: true") }

        if !hasPageHero, let hero = f.hero, !hero.isEmpty {
            lines.append("hero:")
            if let e = hero.eyebrow { lines.append("  \(keyValue("eyebrow", quoted: e))") }
            if let t = hero.title { lines.append("  \(keyValue("title", quoted: t))") }
            if let s = hero.subtitle { lines.append("  \(keyValue("subtitle", quoted: s))") }
        }

        if !hasVideoDetails, let videoMeta = f.videoMeta, !videoMeta.isEmpty {
            lines.append("videoMeta:")
            if let runtime = videoMeta.runtime, !runtime.isEmpty { lines.append("  \(keyValue("runtime", quoted: runtime))") }
            if let platform = videoMeta.platform, !platform.isEmpty { lines.append("  \(keyValue("platform", quoted: platform))") }
            if let transcript = videoMeta.transcriptUrl, !transcript.isEmpty { lines.append("  \(keyValue("transcriptUrl", raw: transcript))") }
            if !videoMeta.credits.isEmpty {
                lines.append("  credits:")
                for credit in videoMeta.credits { lines.append("    - \(yamlScalar(credit))") }
            }
        }

        if !f.blocks.isEmpty {
            lines.append("blocks:")
            for block in f.blocks { lines.append(contentsOf: renderBlock(block)) }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func renderBlock(_ block: ProjectBlock) -> [String] {
        switch block {
        case .projectSnapshot(let b):
            var l = ["  - type: projectSnapshot"]
            l.append("    \(keyValue("projectTitle", quoted: b.projectTitle))")
            l.append("    \(keyValue("summary", quoted: b.summary))")
            l.append("    status: \(b.status.rawValue)")
            l.append("    \(keyValue("ownerTeam", quoted: b.ownerTeam))")
            l.append("    \(keyValue("timelineStart", raw: b.timelineStart))")
            l.append("    \(keyValue("timelineTargetCompletion", raw: b.timelineTargetCompletion))")
            if let budget = b.budgetHeadline, !budget.isEmpty { l.append("    \(keyValue("budgetHeadline", quoted: budget))") }
            return l
        case .keyStats(let b):
            var l = ["  - type: keyStats", "    \(keyValue("title", quoted: b.title))", "    items:"]
            for item in b.items {
                let combinedValue = "\(item.valuePrefix ?? "")\(item.value)"
                l.append("      - \(keyValue("label", quoted: item.label))")
                if let valuePrefix = item.valuePrefix, !valuePrefix.isEmpty {
                    l.append("        \(keyValue("valuePrefix", quoted: valuePrefix))")
                }
                l.append("        \(keyValue("value", quoted: combinedValue))")
                if let unit = item.unit, !unit.isEmpty { l.append("        \(keyValue("unit", quoted: unit))") }
                if let context = item.context, !context.isEmpty { l.append("        \(keyValue("context", quoted: context))") }
                l.append("        \(keyValue("lastUpdated", quoted: item.lastUpdated))")
            }
            return l
        case .goalsMetrics(let b):
            var l = ["  - type: goalsMetrics", "    \(keyValue("title", quoted: b.title))", "    items:"]
            for item in b.items {
                l.append("      - \(keyValue("goal", quoted: item.goal))")
                l.append("        \(keyValue("successMeasure", quoted: item.successMeasure))")
                l.append("        \(keyValue("baseline", quoted: item.baseline))")
                l.append("        \(keyValue("target", quoted: item.target))")
                l.append("        \(keyValue("reportingCadence", quoted: item.reportingCadence))")
            }
            return l
        case .body:
            return ["  - type: body"]
        case .pageHero(let b):
            var l = ["  - type: pageHero"]
            if let e = b.eyebrow, !e.isEmpty { l.append("    \(keyValue("eyebrow", quoted: e))") }
            if let t = b.title, !t.isEmpty { l.append("    \(keyValue("title", quoted: t))") }
            if let s = b.subtitle, !s.isEmpty { l.append("    \(keyValue("subtitle", quoted: s))") }
            return l
        case .headerImage(let b):
            var l = ["  - type: headerImage", "    \(keyValue("src", raw: b.src))"]
            if let alt = b.alt, !alt.isEmpty { l.append("    \(keyValue("alt", quoted: alt))") }
            return l
        case .preface(let b):
            return ["  - type: preface", "    \(keyValue("text", quoted: b.text))"]
        case .caseStudy(let b):
            var l = ["  - type: caseStudy"]
            if let v = b.challenge, !v.isEmpty { l.append("    \(keyValue("challenge", quoted: v))") }
            if let v = b.approach, !v.isEmpty { l.append("    \(keyValue("approach", quoted: v))") }
            if let v = b.outcome, !v.isEmpty { l.append("    \(keyValue("outcome", quoted: v))") }
            if let v = b.role, !v.isEmpty { l.append("    \(keyValue("role", quoted: v))") }
            if let v = b.duration, !v.isEmpty { l.append("    \(keyValue("duration", quoted: v))") }
            return l
        case .videoDetails(let b):
            var l = ["  - type: videoDetails"]
            if let v = b.runtime, !v.isEmpty { l.append("    \(keyValue("runtime", quoted: v))") }
            if let v = b.platform, !v.isEmpty { l.append("    \(keyValue("platform", quoted: v))") }
            if let v = b.transcriptUrl, !v.isEmpty { l.append("    \(keyValue("transcriptUrl", raw: v))") }
            if !b.credits.isEmpty {
                l.append("    credits:")
                for credit in b.credits { l.append("      - \(yamlScalar(credit))") }
            }
            return l
        case .externalLink(let b):
            var l = ["  - type: externalLink", "    \(keyValue("href", raw: b.href))"]
            if let label = b.label, !label.isEmpty { l.append("    \(keyValue("label", quoted: label))") }
            return l
        case .tagList:
            return ["  - type: tagList"]
        case .relatedProjects:
            return ["  - type: relatedProjects"]
        case .quote(let b):
            var l = ["  - type: quote", "    \(keyValue("quote", quoted: b.quote))"]
            if let name = b.attributionName, !name.isEmpty { l.append("    \(keyValue("attributionName", quoted: name))") }
            if let role = b.attributionRoleContext, !role.isEmpty { l.append("    \(keyValue("attributionRoleContext", quoted: role))") }
            if let theme = b.theme, !theme.isEmpty { l.append("    \(keyValue("theme", quoted: theme))") }
            return l
        case .mediaGallery(let b):
            var l = ["  - type: mediaGallery", "    \(keyValue("title", quoted: b.title))", "    items:"]
            for item in b.items {
                l.append("      - \(keyValue("src", raw: item.src))")
                l.append("        \(keyValue("alt", quoted: item.alt))")
                if let caption = item.caption, !caption.isEmpty { l.append("        \(keyValue("caption", quoted: caption))") }
                if let credit = item.credit, !credit.isEmpty { l.append("        \(keyValue("credit", quoted: credit))") }
                if let date = item.date, !date.isEmpty { l.append("        \(keyValue("date", raw: date))") }
                if let location = item.location, !location.isEmpty { l.append("        \(keyValue("location", quoted: location))") }
            }
            return l
        case .videoShowcase(let b):
            var l = ["  - type: videoShowcase", "    variant: \(b.variant.rawValue)"]
            if !b.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                l.append("    \(keyValue("title", quoted: b.title))")
            }
            if let d = b.description, !d.isEmpty { l.append("    \(keyValue("description", quoted: d))") }
            if !b.highlights.isEmpty {
                l.append("    highlights:")
                for h in b.highlights { l.append("      - \(yamlScalar(h))") }
            }
            l.append("    source:")
            switch b.source {
            case .youtube(let id):
                l.append("      kind: youtube")
                l.append("      \(keyValue("videoId", quoted: id))")
            case .vimeo(let id):
                l.append("      kind: vimeo")
                l.append("      \(keyValue("videoId", quoted: id))")
            case .file(let src, let poster, let mimeType, let fallbackUrl, let captions):
                l.append("      kind: file")
                l.append("      \(keyValue("src", raw: src))")
                if let poster, !poster.isEmpty { l.append("      \(keyValue("poster", raw: poster))") }
                if let mimeType, !mimeType.isEmpty { l.append("      \(keyValue("mimeType", quoted: mimeType))") }
                if let fallbackUrl, !fallbackUrl.isEmpty { l.append("      \(keyValue("fallbackUrl", raw: fallbackUrl))") }
                if !captions.isEmpty {
                    l.append("      captions:")
                    for caption in captions {
                        l.append("        - \(keyValue("src", raw: caption.src))")
                        l.append("          \(keyValue("srclang", raw: caption.srclang))")
                        l.append("          \(keyValue("label", quoted: caption.label))")
                        if caption.isDefault { l.append("          default: true") }
                    }
                }
            }
            if let ctaText = b.ctaText, !ctaText.isEmpty { l.append("    \(keyValue("ctaText", quoted: ctaText))") }
            if let ctaHref = b.ctaHref, !ctaHref.isEmpty { l.append("    \(keyValue("ctaHref", raw: ctaHref))") }
            return l
        case .cta(let b):
            var l = ["  - type: cta", "    \(keyValue("title", quoted: b.title))"]
            if let d = b.description, !d.isEmpty { l.append("    \(keyValue("description", quoted: d))") }
            l.append("    links:")
            for link in b.links {
                l.append("      - \(keyValue("label", quoted: link.label))")
                l.append("        \(keyValue("href", raw: link.href))")
            }
            return l
        }
    }

    private static func keyValue(_ key: String, quoted value: String) -> String { "\(key): \(yamlQuoted(value))" }
    private static func keyValue(_ key: String, raw value: String) -> String { "\(key): \(yamlScalar(value))" }

    private static func yamlScalar(_ s: String) -> String {
        if s.isEmpty { return "\"\"" }
        if needsQuoting(s) { return yamlQuoted(s) }
        return s
    }

    private static func yamlQuoted(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func needsQuoting(_ s: String) -> Bool {
        if s.isEmpty { return true }
        let reserved: Set<String> = ["true", "false", "yes", "no", "null", "~"]
        if reserved.contains(s.lowercased()) { return true }
        if Int(s) != nil || Double(s) != nil { return true }
        let problematic: Set<Character> = [":", "#", "-", "?", ",", "[", "]", "{", "}", "&", "*", "!", "|", ">", "'", "\"", "%", "@", "`"]
        if let first = s.first, problematic.contains(first) { return true }
        if s.contains(": ") || s.hasSuffix(":") { return true }
        return false
    }

    private static func yamlDateValue(_ s: String) -> String {
        if s.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil { return s }
        return yamlQuoted(s)
    }
}

