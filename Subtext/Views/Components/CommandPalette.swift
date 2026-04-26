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
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selection: PaletteCommand.ID?
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
        .onAppear { fieldFocused = true }
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
                    ForEach(results) { item in
                        PaletteRow(command: item, query: query)
                            .tag(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(item)
                                dismiss()
                            }
                            .id(item.id)
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
            guard let score = fuzzyScore(haystack: item.searchableText, needle: q) else {
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
        var items: [PaletteCommand] = []

        // Sidebar tabs
        for tab in SidebarTab.allCases {
            items.append(.tab(tab))
        }

        // Home sections + CTAs
        for section in store.splashContent.sections {
            items.append(.section(id: section.id, title: section.heading))
        }
        for cta in store.splashContent.ctas {
            items.append(.cta(id: cta.id, title: cta.name.isEmpty ? cta.heading : cta.name))
        }

        // Projects
        for project in store.projects {
            items.append(.project(
                fileName: project.fileName,
                title: project.frontmatter.title.isEmpty ? project.fileName : project.frontmatter.title
            ))
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

        for section in store.splashContent.sections {
            for (idx, paragraph) in section.bodyParagraphs.enumerated() {
                if paragraph.lowercased().contains(q) {
                    hits.append(.bodyHit(
                        fileLabel: "splash.json · \(section.heading)",
                        snippet: snippet(from: paragraph, matching: q),
                        target: .section(id: section.id, title: section.heading)
                    ))
                    _ = idx
                }
            }
            if let subtitle = section.subtitle, subtitle.lowercased().contains(q) {
                hits.append(.bodyHit(
                    fileLabel: "splash.json · \(section.heading) (subtitle)",
                    snippet: snippet(from: subtitle, matching: q),
                    target: .section(id: section.id, title: section.heading)
                ))
            }
        }

        for project in store.projects {
            let body = project.body
            if body.lowercased().contains(q) {
                hits.append(.bodyHit(
                    fileLabel: "\(project.fileName)",
                    snippet: snippet(from: body, matching: q),
                    target: .project(
                        fileName: project.fileName,
                        title: project.frontmatter.title
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
    private func fuzzyScore(haystack: String, needle: String) -> Int? {
        let h = haystack.lowercased()
        if h.contains(needle) {
            let base = 1000 - abs(h.count - needle.count)
            if h.hasPrefix(needle) { return base + 500 }
            return base
        }
        // Subsequence match: every needle char must appear in order.
        var hIdx = h.startIndex
        var matched = 0
        for ch in needle {
            guard let found = h.range(of: String(ch), range: hIdx..<h.endIndex) else {
                return nil
            }
            hIdx = found.upperBound
            matched += 1
        }
        return matched * 10 - (h.count - needle.count)
    }
}

// MARK: - Commands

enum PaletteCommand: Identifiable, Equatable {
    case tab(SidebarTab)
    case section(id: String, title: String)
    case cta(id: String, title: String)
    case project(fileName: String, title: String)
    case bodyHit(fileLabel: String, snippet: String, target: BodyHitTarget)

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
        }
    }

    var searchableText: String {
        switch self {
        case .tab(let t): t.displayName
        case .section(_, let title): "section \(title)"
        case .cta(_, let title): "cta \(title)"
        case .project(let file, let title): "\(title) \(file)"
        case .bodyHit(let file, let snippet, _): "\(file) \(snippet)"
        }
    }
}

// MARK: - Row

private struct PaletteRow: View {
    let command: PaletteCommand
    let query: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(primary)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if let secondary {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(shortcutHint)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch command {
        case .tab(let t): t.systemImage
        case .section: "square.stack.3d.up"
        case .cta: "cursorarrow.rays"
        case .project: "doc.richtext"
        case .bodyHit: "text.magnifyingglass"
        }
    }

    private var tint: Color {
        switch command {
        case .tab: .secondary
        case .section, .cta: Color.subtextAccent
        case .project: .blue
        case .bodyHit: Color.subtextWarning
        }
    }

    private var primary: String {
        switch command {
        case .tab(let t): t.displayName
        case .section(_, let title): title.isEmpty ? "Untitled section" : title
        case .cta(_, let title): title.isEmpty ? "Unnamed CTA" : title
        case .project(_, let title): title.isEmpty ? "Untitled project" : title
        case .bodyHit(let file, _, _): file
        }
    }

    private var secondary: String? {
        switch command {
        case .tab: nil
        case .section: "Home section"
        case .cta: "Home CTA"
        case .project(let file, _): file
        case .bodyHit(_, let snippet, _): snippet
        }
    }

    private var shortcutHint: String {
        switch command {
        case .tab: "Tab"
        case .section: "Section"
        case .cta: "CTA"
        case .project: "Project"
        case .bodyHit: "Match"
        }
    }
}
