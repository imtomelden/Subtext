import SwiftUI

/// Spotlight-style jump-and-search sheet.
///
/// Two modes, one UI:
/// - **Navigate** (⌘K): fuzzy-matches sidebar tabs, home sections, home
///   CTAs, and project titles. Selecting a result flips the sidebar tab
///   and — where applicable — opens the relevant editor.
/// - **Search** (⌘F): same UI, but also trawls splash body paragraphs
///   and every project body for literal substring hits. Selecting a hit
///   jumps to the owning section/project.
///
/// Results are ranked with a tiny fuzzy scorer so that exact title
/// matches beat body substring hits beat fuzzy-name matches. Good enough
/// for a dozens-of-items catalog without pulling in a proper search lib.
struct CommandPalette: View {
    enum Mode: String, Equatable, Identifiable {
        case navigate
        case search
        var id: String { rawValue }
    }

    let mode: Mode
    var onSelect: (PaletteCommand) -> Void

    @Environment(CMSStore.self) private var store
    @Environment(RecentsStore.self) private var recents
    @Environment(\.dismissModal) private var dismiss
    @State private var query: String = ""
    @State private var selection: PaletteCommand.ID?
    @State private var searchIndex: SearchIndex = .empty
    @FocusState private var fieldFocused: Bool

    var body: some View {
        GlassSurface(prominence: .thick, cornerRadius: SubtextUI.Glass.shellCornerRadius) {
            VStack(spacing: 0) {
                searchField
                    .padding(14)

                Divider()

                resultsList
            }
        }
        .frame(width: 640, height: 440)
        .onAppear {
            fieldFocused = true
            recents.pruneMissingProjectFiles()
            rebuildSearchIndex()
        }
        .onChange(of: store.projects) { _, _ in
            rebuildSearchIndex()
        }
        .onChange(of: store.splashContent.sections) { _, _ in
            rebuildSearchIndex()
        }
        .onChange(of: store.splashContent.ctas) { _, _ in
            rebuildSearchIndex()
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    // MARK: - Top search field

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: mode == .search ? "magnifyingglass" : "command")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $query)
                .font(.title3)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onSubmit(performPrimarySelection)
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var placeholder: String {
        mode == .search
            ? "Search inside splash, site, and project bodies…"
            : "Jump to a section, CTA, or project…"
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        let results = rankedResults
        if results.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    if mode == .navigate && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        groupedNavigateResults(results: results)
                    } else {
                        ForEach(results) { item in
                            paletteRow(item)
                        }
                    }
                }
                .listStyle(.plain)
                .onChange(of: query) { _, _ in
                    selection = results.first?.id
                }
                .onAppear {
                    selection = results.first?.id
                }
                .onChange(of: selection) { _, newValue in
                    if let id = newValue {
                        withAnimation(.linear(duration: 0.08)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func groupedNavigateResults(results: [PaletteCommand]) -> some View {
        let recentItems = results.filter { if case .recent = $0 { return true }; return false }
        let recentFileNames = Set(recentItems.compactMap {
            if case .recent(let f, _) = $0 { return f }; return nil
        })
        let tabs = results.filter { if case .tab = $0 { return true }; return false }
        let sections = results.filter { if case .section = $0 { return true }; return false }
        let ctas = results.filter { if case .cta = $0 { return true }; return false }
        // Suppress projects already shown under "Recent" to avoid duplication.
        let projects = results.filter {
            if case .project(let f, _) = $0 { return !recentFileNames.contains(f) }; return false
        }
        let insertItems = results.filter { if case .insertBlock = $0 { return true }; return false }

        if !recentItems.isEmpty {
            Section(header: groupHeader("Recent")) {
                ForEach(recentItems) { item in paletteRow(item) }
            }
        }
        if !tabs.isEmpty {
            Section(header: groupHeader("Navigation")) {
                ForEach(tabs) { item in paletteRow(item) }
            }
        }
        if !sections.isEmpty {
            Section(header: groupHeader("Sections")) {
                ForEach(sections) { item in paletteRow(item) }
            }
        }
        if !ctas.isEmpty {
            Section(header: groupHeader("CTAs")) {
                ForEach(ctas) { item in paletteRow(item) }
            }
        }
        if !projects.isEmpty {
            Section(header: groupHeader("Projects")) {
                ForEach(projects) { item in paletteRow(item) }
            }
        }
        if !insertItems.isEmpty {
            Section(header: groupHeader("Insert Block")) {
                ForEach(insertItems) { item in paletteRow(item) }
            }
        }
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Tokens.Text.tertiary)
            .kerning(0.6)
            .listRowBackground(Tokens.Background.sunken)
    }

    private func paletteRow(_ item: PaletteCommand) -> some View {
        PaletteRow(
            command: item,
            query: query,
            onRemoveRecent: { name in
                recents.remove(fileName: name)
            }
        )
            .tag(item.id)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(item)
                dismiss()
            }
            .id(item.id)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: query.isEmpty ? "sparkle" : "questionmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(query.isEmpty ? "Start typing to search." : "No matches for “\(query)”.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func performPrimarySelection() {
        guard let id = selection,
              let command = rankedResults.first(where: { $0.id == id })
        else { return }
        onSelect(command)
        dismiss()
    }

    private func moveSelection(by delta: Int) {
        let results = rankedResults
        guard !results.isEmpty else { return }
        let currentIdx = results.firstIndex(where: { $0.id == selection }) ?? -1
        let nextIdx = min(max(currentIdx + delta, 0), results.count - 1)
        selection = results[nextIdx].id
    }

    // MARK: - Scoring / ranking

    private var rankedResults: [PaletteCommand] {
        let items = allItems()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            return Array(items.prefix(80))
        }
        let scored: [(PaletteCommand, Int)] = items.compactMap { item in
            guard let score = fuzzyScore(haystackLowercased: item.searchableText.lowercased(), needleLowercased: q) else {
                return nil
            }
            return (item, score)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(80)
            .map { $0.0 }
    }

    private func allItems() -> [PaletteCommand] {
        var items = searchIndex.baseItems

        if mode == .navigate {
            // Prepend recents that still exist in the project list.
            let existingFileNames = Set(store.projects.map { $0.fileName })
            let recentItems: [PaletteCommand] = recents.recentFileNames
                .filter { existingFileNames.contains($0) }
                .compactMap { fileName in
                    guard let project = store.projects.first(where: { $0.fileName == fileName }) else { return nil }
                    let title = project.frontmatter.title.isEmpty ? fileName : project.frontmatter.title
                    return .recent(fileName: fileName, title: title)
                }
            items = recentItems + items

            // Insert-block actions when a project is open.
            if store.selectedProjectFileName != nil {
                items.append(contentsOf: ProjectBlock.Kind.allCases.map { .insertBlock(kind: $0) })
            }
        }

        // In search mode, include content hits so users can jump to the
        // source of a remembered phrase.
        if mode == .search, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(contentsOf: contentHits())
        }

        return items
    }

    private func contentHits() -> [PaletteCommand] {
        let q = query.lowercased()
        var hits: [PaletteCommand] = []

        for section in searchIndex.sectionBodies {
            for paragraph in section.paragraphs {
                if paragraph.lowercased.contains(q) {
                    hits.append(.bodyHit(
                        fileLabel: "splash.json · \(section.title)",
                        snippet: snippet(from: paragraph.raw, matching: q),
                        target: .section(id: section.id, title: section.title)
                    ))
                }
            }
            if let subtitle = section.subtitle, subtitle.lowercased.contains(q) {
                hits.append(.bodyHit(
                    fileLabel: "splash.json · \(section.title) (subtitle)",
                    snippet: snippet(from: subtitle.raw, matching: q),
                    target: .section(id: section.id, title: section.title)
                ))
            }
        }

        for project in searchIndex.projectBodies {
            if project.bodyLowercased.contains(q) {
                hits.append(.bodyHit(
                    fileLabel: project.fileName,
                    snippet: snippet(from: project.bodyRaw, matching: q),
                    target: .project(
                        fileName: project.fileName,
                        title: project.title
                    )
                ))
            }
        }

        return hits
    }

    private func snippet(from text: String, matching needle: String) -> String {
        let lower = text.lowercased()
        guard let range = lower.range(of: needle) else { return String(text.prefix(120)) }
        let start = text.index(range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 80, limitedBy: text.endIndex) ?? text.endIndex
        let prefix = start > text.startIndex ? "…" : ""
        let suffix = end < text.endIndex ? "…" : ""
        return prefix + String(text[start..<end])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces) + suffix
    }

    /// Simple fuzzy scorer: returns `nil` on no match, otherwise a
    /// non-negative score where higher is better. Exact substring hits
    /// dominate, then prefix matches, then scattered subsequence matches.
    private func fuzzyScore(haystackLowercased h: String, needleLowercased needle: String) -> Int? {
        fuzzyMatchDetail(haystackLowercased: h, needleLowercased: needle)?.score
    }

    /// Shared with row highlighting — same thresholds as ranking.
    private func fuzzyMatchDetail(haystackLowercased h: String, needleLowercased needle: String) -> (score: Int, indices: Set<Int>)? {
        if h.contains(needle) {
            let base = 1000 - abs(h.count - needle.count)
            let score = h.hasPrefix(needle) ? base + 500 : base
            guard let range = h.range(of: needle) else { return (score, []) }
            let start = h.distance(from: h.startIndex, to: range.lowerBound)
            let end = h.distance(from: h.startIndex, to: range.upperBound)
            return (score, Set(start..<end))
        }
        var hIdx = h.startIndex
        var matched = 0
        var indices = Set<Int>()
        for ch in needle {
            guard let found = h.range(of: String(ch), range: hIdx..<h.endIndex) else {
                return nil
            }
            indices.insert(h.distance(from: h.startIndex, to: found.lowerBound))
            hIdx = found.upperBound
            matched += 1
        }
        let score = matched * 10 - (h.count - needle.count)
        return (score, indices)
    }

    private func rebuildSearchIndex() {
        searchIndex = SearchIndex.build(
            splashSections: store.splashContent.sections,
            splashCTAs: store.splashContent.ctas,
            projects: store.projects
        )
    }
}

private struct SearchIndex {
    struct IndexedString {
        let raw: String
        let lowercased: String
    }

    struct SectionBodyIndex {
        let id: String
        let title: String
        let subtitle: IndexedString?
        let paragraphs: [IndexedString]
    }

    struct ProjectBodyIndex {
        let fileName: String
        let title: String
        let bodyRaw: String
        let bodyLowercased: String
    }

    let baseItems: [PaletteCommand]
    let sectionBodies: [SectionBodyIndex]
    let projectBodies: [ProjectBodyIndex]

    static let empty = SearchIndex(baseItems: [], sectionBodies: [], projectBodies: [])

    static func build(
        splashSections: [SplashSection],
        splashCTAs: [SplashCTA],
        projects: [ProjectDocument]
    ) -> SearchIndex {
        var items: [PaletteCommand] = SidebarTab.allCases.map { .tab($0) }
        items.append(contentsOf: splashSections.map { .section(id: $0.id, title: $0.heading) })
        items.append(contentsOf: splashCTAs.map {
            .cta(id: $0.id, title: $0.name.isEmpty ? $0.heading : $0.name)
        })
        items.append(contentsOf: projects.map {
            .project(fileName: $0.fileName, title: $0.frontmatter.title.isEmpty ? $0.fileName : $0.frontmatter.title)
        })

        let sectionBodies = splashSections.map { section in
            SectionBodyIndex(
                id: section.id,
                title: section.heading,
                subtitle: section.subtitle.map { IndexedString(raw: $0, lowercased: $0.lowercased()) },
                paragraphs: section.bodyParagraphs.map { IndexedString(raw: $0, lowercased: $0.lowercased()) }
            )
        }

        let projectBodies = projects.map { project in
            ProjectBodyIndex(
                fileName: project.fileName,
                title: project.frontmatter.title,
                bodyRaw: project.body,
                bodyLowercased: project.body.lowercased()
            )
        }

        return SearchIndex(baseItems: items, sectionBodies: sectionBodies, projectBodies: projectBodies)
    }
}

// MARK: - Commands

enum PaletteCommand: Identifiable, Equatable {
    case tab(SidebarTab)
    case section(id: String, title: String)
    case cta(id: String, title: String)
    case project(fileName: String, title: String)
    case bodyHit(fileLabel: String, snippet: String, target: BodyHitTarget)
    case recent(fileName: String, title: String)
    case insertBlock(kind: ProjectBlock.Kind)

    enum BodyHitTarget: Equatable {
        case section(id: String, title: String)
        case project(fileName: String, title: String)
    }

    var id: String {
        switch self {
        case .tab(let t): "tab.\(t.rawValue)"
        case .section(let id, _): "section.\(id)"
        case .cta(let id, _): "cta.\(id)"
        case .project(let file, _): "project.\(file)"
        case .bodyHit(let file, let snippet, _): "hit.\(file).\(snippet.hashValue)"
        case .recent(let file, _): "recent.\(file)"
        case .insertBlock(let kind): "insert.\(kind.rawValue)"
        }
    }

    var searchableText: String {
        switch self {
        case .tab(let t): t.displayName
        case .section(_, let title): "section \(title)"
        case .cta(_, let title): "cta \(title)"
        case .project(let file, let title): "\(title) \(file)"
        case .bodyHit(let file, let snippet, _): "\(file) \(snippet)"
        case .recent(let file, let title): "recent \(title) \(file)"
        case .insertBlock(let kind): "insert add block \(kind.displayName)"
        }
    }
}

// MARK: - Row

private struct PaletteRow: View {
    let command: PaletteCommand
    let query: String
    var onRemoveRecent: (String) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                paletteHighlightedText(
                    primary,
                    indices: primaryHighlightIndices,
                    font: .callout,
                    baseWeight: .medium,
                    baseColor: Tokens.Text.primary
                )
                .lineLimit(1)
                if let secondary {
                    paletteHighlightedText(
                        secondary,
                        indices: secondaryHighlightIndices,
                        font: .caption,
                        baseWeight: .regular,
                        baseColor: Tokens.Text.tertiary
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
            }

            Spacer()

            if case .recent(let file, _) = command {
                Button {
                    onRemoveRecent(file)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Remove from recents")
                .accessibilityLabel("Remove from recents")
            }

            if let keys = shortcutKeys {
                KeyCapsuleHint(keys: keys)
            }
        }
        .padding(.vertical, 3)
        .frame(minHeight: 36)
    }

    private var qFocused: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var qLower: String {
        qFocused.lowercased()
    }

    private var primaryHighlightIndices: Set<Int>? {
        guard !qLower.isEmpty else { return nil }
        return PaletteRow.fuzzyMatchIndices(haystack: primary, needleLowercased: qLower)
    }

    private var secondaryHighlightIndices: Set<Int>? {
        guard !qLower.isEmpty, let secondary else { return nil }
        if case .bodyHit = command {
            return PaletteRow.literalMatchIndices(full: secondary, substringLowercased: qLower)
        }
        return PaletteRow.fuzzyMatchIndices(haystack: secondary, needleLowercased: qLower)
    }

    private static func fuzzyMatchIndices(haystack: String, needleLowercased needle: String) -> Set<Int>? {
        guard !needle.isEmpty else { return nil }
        let h = haystack.lowercased()
        if h.contains(needle) {
            guard let range = h.range(of: needle) else { return nil }
            let start = h.distance(from: h.startIndex, to: range.lowerBound)
            let end = h.distance(from: h.startIndex, to: range.upperBound)
            return Set(start..<end)
        }
        var hIdx = h.startIndex
        var indices = Set<Int>()
        for ch in needle {
            guard let found = h.range(of: String(ch), range: hIdx..<h.endIndex) else {
                return nil
            }
            indices.insert(h.distance(from: h.startIndex, to: found.lowerBound))
            hIdx = found.upperBound
        }
        return indices
    }

    private static func literalMatchIndices(full: String, substringLowercased needle: String) -> Set<Int>? {
        guard !needle.isEmpty else { return nil }
        guard let range = full.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        let start = full.distance(from: full.startIndex, to: range.lowerBound)
        let end = full.distance(from: full.startIndex, to: range.upperBound)
        return Set(start..<end)
    }

    /// Maps fuzzy indices computed on lowercased string onto `haystack`'s Characters
    /// (safe when lengths match — true for normalization-insensitive edits in Subtext.)
    private func paletteHighlightedText(
        _ haystack: String,
        indices: Set<Int>?,
        font: Font,
        baseWeight: Font.Weight,
        baseColor: Color
    ) -> Text {
        guard let indices, !indices.isEmpty else {
            return Text(haystack)
                .font(font.weight(baseWeight))
                .foregroundStyle(baseColor)
        }
        let accent = Color.subtextAccent
        var output = AttributedString()
        for (offset, character) in haystack.enumerated() {
            let isHit = indices.contains(offset)
            var piece = AttributedString(String(character))
            piece.swiftUI.font = font.weight(isHit ? .semibold : baseWeight)
            piece.swiftUI.foregroundColor = isHit ? accent : baseColor
            output.append(piece)
        }
        return Text(output)
    }

    private var iconName: String {
        switch command {
        case .tab(let t): t.systemImage
        case .section: "square.stack.3d.up"
        case .cta: "cursorarrow.rays"
        case .project: "doc.richtext"
        case .bodyHit: "text.magnifyingglass"
        case .recent: "clock"
        case .insertBlock(let kind): kind.systemImage
        }
    }

    private var tint: Color {
        switch command {
        case .tab: Tokens.Text.secondary
        case .section, .cta: Color.subtextAccent
        case .project: .blue
        case .bodyHit: Color.subtextWarning
        case .recent: .secondary
        case .insertBlock: Color.subtextAccent
        }
    }

    private var primary: String {
        switch command {
        case .tab(let t): t.displayName
        case .section(_, let title): title.isEmpty ? "Untitled section" : title
        case .cta(_, let title): title.isEmpty ? "Unnamed CTA" : title
        case .project(_, let title): title.isEmpty ? "Untitled project" : title
        case .bodyHit(let file, _, _): file
        case .recent(_, let title): title.isEmpty ? "Untitled project" : title
        case .insertBlock(let kind): "Insert \(kind.displayName)"
        }
    }

    private var secondary: String? {
        switch command {
        case .tab: nil
        case .section: "Home section"
        case .cta: "Home CTA"
        case .project(let file, _): file
        case .bodyHit(_, let snippet, _): snippet
        case .recent(let file, _): "Recent · \(file)"
        case .insertBlock: "Add to current project"
        }
    }

    private var shortcutKeys: [String]? {
        switch command {
        case .tab(let t):
            switch t {
            case .home:     return ["⌘", "1"]
            case .projects: return ["⌘", "2"]
            case .settings: return ["⌘", ","]
            }
        case .recent, .section, .cta, .project, .bodyHit, .insertBlock:
            return nil
        }
    }
}

// MARK: - Key Capsule Hint

private struct KeyCapsuleHint: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Tokens.Text.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Tokens.Background.elevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Tokens.Border.subtle, lineWidth: 0.5)
                            )
                    )
            }
        }
    }
}
