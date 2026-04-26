import SwiftUI

struct HomeEditorView: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density
    @State private var showVisualPicker = false
    @State private var showHistory = false
    @State private var showSourcePreview = false
    @State private var homeSearchText = ""
    @FocusState private var homeSearchFocused: Bool

    var body: some View {
        @Bindable var store = store

        mainCanvas
            .slidingPanel(isPresented: store.editingSectionID != nil) {
                if let id = store.editingSectionID, let binding = store.binding(forSection: id) {
                    SectionEditorPanel(section: binding) {
                        store.editingSectionID = nil
                    }
                }
            }
            .slidingPanel(isPresented: store.editingCTAID != nil) {
                if let id = store.editingCTAID, let binding = store.binding(forCTA: id) {
                    CTAEditorPanel(cta: binding) {
                        store.editingCTAID = nil
                    }
                }
            }
            .sheet(isPresented: $showVisualPicker) {
                let options = SplashSection.addSectionOptions
                let items: [PickerItem<SplashSection.AddSectionOption>] = options.map { option in
                    PickerItem(
                        id: option.id,
                        kind: option,
                        displayName: option.displayName,
                        systemImage: option.systemImage
                    )
                }
                BlockPicker(title: "Add section", items: items) { option in
                    store.addSection(option: option)
                }
            }
            .sheet(isPresented: $showHistory) {
                HomeHistoryPanel()
            }
            .sheet(isPresented: $showSourcePreview) {
                SourcePreviewDrawer(source: .splash(store.splashContent)) {
                    showSourcePreview = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .subtextNewItem)) { _ in
                showVisualPicker = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemUp)) { _ in
                moveSelectedItem(by: -1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemDown)) { _ in
                moveSelectedItem(by: 1)
            }
    }

    private func moveSelectedItem(by delta: Int) {
        if let id = store.editingSectionID,
           let idx = store.splashContent.sections.firstIndex(where: { $0.id == id })
        {
            let dest = clamp(idx + delta, min: 0, max: store.splashContent.sections.count - 1)
            guard dest != idx else { return }
            // SwiftUI's `move(fromOffsets:toOffset:)` expects the
            // insertion index — for a forward move that's `dest + 1`.
            let destination = delta > 0 ? dest + 1 : dest
            store.moveSection(from: IndexSet(integer: idx), to: destination)
        } else if let id = store.editingCTAID,
                  let idx = store.splashContent.ctas.firstIndex(where: { $0.id == id })
        {
            let dest = clamp(idx + delta, min: 0, max: store.splashContent.ctas.count - 1)
            guard dest != idx else { return }
            let destination = delta > 0 ? dest + 1 : dest
            store.moveCTA(from: IndexSet(integer: idx), to: destination)
        }
    }

    private func clamp(_ value: Int, min lo: Int, max hi: Int) -> Int {
        Swift.max(lo, Swift.min(hi, value))
    }

    @ViewBuilder
    private var mainCanvas: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: density.sectionOuterSpacing) {
                    header

                    homeSearchField
                        .padding(.horizontal, density.sectionOuterSpacing)

                    sectionsList
                        .padding(.horizontal, density.sectionOuterSpacing)

                    ctasList
                        .padding(.horizontal, density.sectionOuterSpacing)
                        .padding(.bottom, 80)
                }
                .padding(.top, density.canvasTopPadding)
            }
            .onChange(of: store.editingSectionID) { _, newValue in
                if let id = newValue { proxy.scrollTo(id, anchor: .center) }
            }
            .onChange(of: store.editingCTAID) { _, newValue in
                if let id = newValue { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Home")
                    .font(.largeTitle.weight(.semibold))
                Text("Editing splash.json — sections render top to bottom on imtomelden.com.")
                    .font(SubtextUI.Typography.body)
                    .foregroundStyle(.secondary)
                    .opacity(homeSearchFocused ? 0.75 : 1)
            }
            Spacer()
            toolbarButtons
                .opacity(homeSearchFocused ? 0.45 : 1)
                .allowsHitTesting(!homeSearchFocused)
        }
        .padding(.horizontal, density.sectionOuterSpacing)
    }

    @ViewBuilder
    private var homeSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search sections and CTAs", text: $homeSearchText)
                .textFieldStyle(.plain)
                .focused($homeSearchFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(homeSearchFocused ? Color.subtextAccent.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 0.8)
        }
        .accessibilityLabel("Search sections and CTAs")
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        HStack(spacing: 10) {
            RevealInFinderButton(
                url: RepoConstants.splashFile,
                helpText: "Reveal splash.json in Finder"
            )

            Button {
                showSourcePreview = true
            } label: {
                Image(systemName: "curlybraces")
            }
            .help("Preview splash.json source")
            .accessibilityLabel("Preview source")
            .buttonStyle(.bordered)

            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .help("Version history")
            .accessibilityLabel("Version history")
            .buttonStyle(.bordered)

            Button {
                showVisualPicker = true
            } label: {
                Label("Add section", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.subtextAccent)
        }
    }

    private var filteredSections: [SplashSection] {
        let q = homeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = store.splashContent.sections
        guard !q.isEmpty else { return all }
        return all.filter { sectionMatchesSearch($0, q: q) }
    }

    private var filteredCTAs: [SplashCTA] {
        let q = homeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = store.splashContent.ctas
        guard !q.isEmpty else { return all }
        return all.filter { ctaMatchesSearch($0, q: q) }
    }

    private func sectionMatchesSearch(_ section: SplashSection, q: String) -> Bool {
        if section.heading.lowercased().contains(q) { return true }
        if section.id.lowercased().contains(q) { return true }
        if let sub = section.subtitle, sub.lowercased().contains(q) { return true }
        if section.previewText.lowercased().contains(q) { return true }
        if section.visual.kind.displayName.lowercased().contains(q) { return true }
        return false
    }

    private func ctaMatchesSearch(_ cta: SplashCTA, q: String) -> Bool {
        cta.name.lowercased().contains(q)
            || cta.heading.lowercased().contains(q)
            || cta.subtitle.lowercased().contains(q)
            || cta.href.lowercased().contains(q)
            || cta.id.lowercased().contains(q)
    }

    private var isHomeSearchActive: Bool {
        !homeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var sectionsList: some View {
        let sections = filteredSections
        let total = store.splashContent.sections.count

        VStack(alignment: .leading, spacing: density.listRowSpacing) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading(
                    title: "Sections",
                    count: isHomeSearchActive ? sections.count : total,
                    countSuffix: isHomeSearchActive && total != sections.count ? " of \(total)" : nil
                )
                Spacer()
                if !isHomeSearchActive, sections.count > 1 {
                    reorderHint
                }
            }

            if store.splashContent.sections.isEmpty {
                emptyState(
                    title: "No sections yet",
                    hint: "Add your first home page section using the Add button above."
                )
            } else if sections.isEmpty {
                emptyState(
                    title: "No sections match your search",
                    hint: "Try a different term or clear the search field."
                )
            } else if isHomeSearchActive {
                searchActiveReorderHint
                ForEach(sections) { section in
                    SectionCardView(
                        section: section,
                        reorderControls: nil,
                        onEdit: { store.editingSectionID = section.id },
                        onDelete: { store.deleteSection(id: section.id) }
                    )
                    .id(section.id)
                }
            } else {
                ReorderableVStack(
                    items: sections,
                    spacing: density.listRowSpacing,
                    onMove: { source, destination in
                        store.moveSection(from: source, to: destination)
                    }
                ) { section, controls in
                    SectionCardView(
                        section: section,
                        reorderControls: controls,
                        onEdit: { store.editingSectionID = section.id },
                        onDelete: { store.deleteSection(id: section.id) }
                    )
                    .id(section.id)
                }
            }
        }
    }

    @ViewBuilder
    private var searchActiveReorderHint: some View {
        Text("Clear search to reorder sections.")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var ctasList: some View {
        let ctas = filteredCTAs
        let totalCTAs = store.splashContent.ctas.count

        VStack(alignment: .leading, spacing: density.listRowSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                sectionHeading(
                    title: "Call-to-action cards",
                    count: isHomeSearchActive ? ctas.count : totalCTAs,
                    countSuffix: isHomeSearchActive && totalCTAs != ctas.count ? " of \(totalCTAs)" : nil
                )
                if !isHomeSearchActive, ctas.count > 1 {
                    reorderHint
                }
                Spacer()
                Button {
                    store.addCTA()
                } label: {
                    Label("Add CTA", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .tint(Color.subtextAccent)
            }

            if store.splashContent.ctas.isEmpty {
                emptyState(title: "No CTAs yet", hint: "CTAs are the two prominent buttons after the sections list.")
            } else if ctas.isEmpty {
                emptyState(
                    title: "No CTAs match your search",
                    hint: "Try a different term or clear the search field."
                )
            } else if isHomeSearchActive {
                Text("Clear search to reorder CTAs.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                ForEach(ctas) { cta in
                    CTACardView(
                        cta: cta,
                        reorderControls: nil,
                        onEdit: { store.editingCTAID = cta.id },
                        onDelete: { store.deleteCTA(id: cta.id) }
                    )
                    .id(cta.id)
                }
            } else {
                ReorderableVStack(
                    items: ctas,
                    spacing: density.listRowSpacing,
                    onMove: { source, destination in
                        store.moveCTA(from: source, to: destination)
                    }
                ) { cta, controls in
                    CTACardView(
                        cta: cta,
                        reorderControls: controls,
                        onEdit: { store.editingCTAID = cta.id },
                        onDelete: { store.deleteCTA(id: cta.id) }
                    )
                    .id(cta.id)
                }
            }
        }
    }

    @ViewBuilder
    private var reorderHint: some View {
        Label("Use arrows to reorder", systemImage: "arrow.up.arrow.down")
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func sectionHeading(title: String, count: Int, countSuffix: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            HStack(spacing: 0) {
                Text("\(count)")
                if let countSuffix {
                    Text(countSuffix)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.4), in: Capsule())
        }
    }

    @ViewBuilder
    private func emptyState(title: String, hint: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(SubtextUI.Typography.bodyStrong)
            Text(hint).font(SubtextUI.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial.opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                }
        )
    }
}
