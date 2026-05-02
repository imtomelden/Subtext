import SwiftUI

/// Renders the inline-editing canvas for home sections and CTAs.
///
/// Replaces the `sectionsList` + `ctasList` views in `HomeEditorView`.
/// Each item is a `SectionBlockHostView` / `CTABlockHostView` that
/// expands in-place when tapped — no side panel.
///
/// `selection` is the shared `BlockSelection` observable; expanding a
/// block sets `selection.editingID` and collapses any previously open block.
struct BlockCanvasView: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density

    let searchText: String
    var selection: BlockSelection
    var onActivateSlash: () -> Void

    @State private var sectionDrag = DragReorderState(spacing: 8)
    @State private var ctaDrag = DragReorderState(spacing: 8)

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: density.sectionOuterSpacing) {
            sectionsList
            ctasList
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sectionsList: some View {
        let sections = filteredSections
        let total = store.splashContent.sections.count

        VStack(alignment: .leading, spacing: density.listRowSpacing) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading(
                    title: "Sections",
                    count: isSearchActive ? sections.count : total,
                    countSuffix: isSearchActive && total != sections.count ? " of \(total)" : nil
                )
                Spacer()
                if !isSearchActive, sections.count > 1 {
                    reorderHint
                }
            }

            Rectangle()
                .fill(Tokens.Border.subtle)
                .frame(height: 1)

            if store.splashContent.sections.isEmpty {
                emptyState(
                    title: "No sections yet",
                    hint: "Press / or click Add section to create your first home page section."
                ) {
                    onActivateSlash()
                }
            } else if sections.isEmpty {
                emptyState(
                    title: "No sections match your search",
                    hint: "Try a different term or clear the search field."
                )
            } else if isSearchActive {
                Text("Clear search to reorder sections.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
                ForEach(sections) { section in
                    sectionRow(section: section, reorderControls: nil)
                        .id(section.id)
                }
            } else {
                ReorderableVStack(
                    items: sections,
                    spacing: 0,
                    dragState: sectionDrag,
                    onMove: { store.moveSection(from: $0, to: $1) }
                ) { section, controls in
                    sectionRow(section: section, reorderControls: controls)
                        .id(section.id)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionRow(section: SplashSection, reorderControls: AnyView?) -> some View {
        @Bindable var store = store
        if let binding = store.binding(forSection: section.id) {
            SectionBlockHostView(
                section: binding,
                isEditing: selection.isEditing(section.id),
                reorderControls: reorderControls,
                onToggleEdit: { selection.toggle(section.id) },
                onDelete: { store.deleteSection(id: section.id) }
            )
        }
    }

    // MARK: - CTAs

    @ViewBuilder
    private var ctasList: some View {
        @Bindable var store = store
        let ctas = filteredCTAs
        let totalCTAs = store.splashContent.ctas.count

        VStack(alignment: .leading, spacing: density.listRowSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                sectionHeading(
                    title: "Call-to-action cards",
                    count: isSearchActive ? ctas.count : totalCTAs,
                    countSuffix: isSearchActive && totalCTAs != ctas.count ? " of \(totalCTAs)" : nil
                )
                if !isSearchActive, ctas.count > 1 {
                    reorderHint
                }
                Spacer()
                Button {
                    store.addCTA()
                } label: {
                    Text("+ Add CTA")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.subtextAccent)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Tokens.Border.subtle)
                .frame(height: 1)

            if store.splashContent.ctas.isEmpty {
                emptyState(
                    title: "No CTAs yet",
                    hint: "CTAs are the two prominent buttons after the sections list."
                )
            } else if ctas.isEmpty {
                emptyState(
                    title: "No CTAs match your search",
                    hint: "Try a different term or clear the search field."
                )
            } else if isSearchActive {
                Text("Clear search to reorder CTAs.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
                ForEach(ctas) { cta in
                    ctaRow(cta: cta, reorderControls: nil)
                        .id(cta.id)
                }
            } else {
                ReorderableVStack(
                    items: ctas,
                    spacing: 0,
                    dragState: ctaDrag,
                    onMove: { store.moveCTA(from: $0, to: $1) }
                ) { cta, controls in
                    ctaRow(cta: cta, reorderControls: controls)
                        .id(cta.id)
                }
            }
        }
    }

    @ViewBuilder
    private func ctaRow(cta: SplashCTA, reorderControls: AnyView?) -> some View {
        @Bindable var store = store
        if let binding = store.binding(forCTA: cta.id) {
            CTABlockHostView(
                cta: binding,
                isEditing: selection.isEditing(cta.id),
                reorderControls: reorderControls,
                onToggleEdit: { selection.toggle(cta.id) },
                onDelete: { store.deleteCTA(id: cta.id) }
            )
        }
    }

    // MARK: - Filtering

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSections: [SplashSection] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = store.splashContent.sections
        guard !q.isEmpty else { return all }
        return all.filter { sectionMatchesSearch($0, q: q) }
    }

    private var filteredCTAs: [SplashCTA] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = store.splashContent.ctas
        guard !q.isEmpty else { return all }
        return all.filter { ctaMatchesSearch($0, q: q) }
    }

    private func sectionMatchesSearch(_ section: SplashSection, q: String) -> Bool {
        section.heading.lowercased().contains(q)
            || section.id.lowercased().contains(q)
            || section.subtitle?.lowercased().contains(q) == true
            || section.previewText.lowercased().contains(q)
            || section.visual.kind.displayName.lowercased().contains(q)
    }

    private func ctaMatchesSearch(_ cta: SplashCTA, q: String) -> Bool {
        cta.name.lowercased().contains(q)
            || cta.heading.lowercased().contains(q)
            || cta.subtitle.lowercased().contains(q)
            || cta.href.lowercased().contains(q)
            || cta.id.lowercased().contains(q)
    }

    // MARK: - Shared UI

    @ViewBuilder
    private var reorderHint: some View {
        Label("Drag to reorder  ·  ⌘↑↓", systemImage: "line.3.horizontal")
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func sectionHeading(title: String, count: Int, countSuffix: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.Text.tertiary)
                .tracking(0.9)
            HStack(spacing: 0) {
                Text("\(count)")
                if let countSuffix { Text(countSuffix) }
            }
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Tokens.Text.tertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Capsule().fill(Tokens.Fill.tag))
        }
    }

    @ViewBuilder
    private func emptyState(title: String, hint: String, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 6) {
            if let action {
                Button(action: action) {
                    Text(title).font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.subtextAccent)
            } else {
                Text(title).font(.callout.weight(.medium))
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Text(hint)
                .font(.caption)
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
