import SwiftUI

struct HomeEditorView: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density
    @Environment(FocusModeController.self) private var focusMode
    @State private var showHistory = false
    @State private var showSourcePreview = false
    @State private var homeSearchText = ""
    @FocusState private var homeSearchFocused: Bool

    // Phase 4 — inline canvas state
    @State private var blockSelection = BlockSelection()
    @State private var slashController = SlashCommandController()

    var body: some View {
        @Bindable var store = store

        mainCanvas
            // Slash command overlay — replaces the old BlockPicker sheet.
            .subtextModal(
                item: slashModalItem,
                style: { _ in .command }
            ) { _ in
                SlashCommandMenu(query: $slashController.query) { option in
                    store.addSection(option: option)
                    // Auto-select the new section for immediate editing.
                    if let newSection = store.splashContent.sections.last {
                        blockSelection.select(newSection.id)
                    }
                    slashController.dismiss()
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
                slashController.activate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemUp)) { _ in
                moveSelectedItem(by: -1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemDown)) { _ in
                moveSelectedItem(by: 1)
            }
            // Sync store-driven selection (e.g. undo/redo, add-then-auto-select)
            // into the local BlockSelection so the inline editor opens.
            .onChange(of: store.editingSectionID) { _, newValue in
                if let id = newValue, !blockSelection.isEditing(id) {
                    blockSelection.select(id)
                }
            }
            .onChange(of: store.editingCTAID) { _, newValue in
                if let id = newValue, !blockSelection.isEditing(id) {
                    blockSelection.select(id)
                }
            }
    }

    // MARK: - Slash modal binding

    private var slashModalItem: Binding<SlashCommandController?> {
        Binding(
            get: { slashController.isPresented ? slashController : nil },
            set: { if $0 == nil { slashController.dismiss() } }
        )
    }

    // MARK: - Keyboard reorder

    private func moveSelectedItem(by delta: Int) {
        guard let id = blockSelection.editingID else { return }
        if let idx = store.splashContent.sections.firstIndex(where: { $0.id == id }) {
            let dest = clamp(idx + delta, min: 0, max: store.splashContent.sections.count - 1)
            guard dest != idx else { return }
            store.moveSection(from: IndexSet(integer: idx), to: delta > 0 ? dest + 1 : dest)
        } else if let idx = store.splashContent.ctas.firstIndex(where: { $0.id == id }) {
            let dest = clamp(idx + delta, min: 0, max: store.splashContent.ctas.count - 1)
            guard dest != idx else { return }
            store.moveCTA(from: IndexSet(integer: idx), to: delta > 0 ? dest + 1 : dest)
        }
    }

    private func clamp(_ value: Int, min lo: Int, max hi: Int) -> Int {
        Swift.max(lo, Swift.min(hi, value))
    }

    // MARK: - Main canvas

    @ViewBuilder
    private var mainCanvas: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: density.sectionOuterSpacing) {
                    header
                        .focusModeChrome()

                    homeSearchField
                        .focusModeChrome()

                    BlockCanvasView(
                        searchText: homeSearchText,
                        selection: blockSelection,
                        onActivateSlash: { slashController.activate() }
                    )
                    .padding(.horizontal, 40)
                    .padding(.bottom, 80)
                }
                .padding(.top, density.canvasTopPadding)
            }
            .onChange(of: blockSelection.editingID) { _, newValue in
                if let id = newValue {
                    withAnimation(Motion.spring) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Home")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Tokens.Text.primary)
                    .tracking(-0.78)
                Text("Editing splash.json — sections render top to bottom on imtomelden.com.")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .opacity(homeSearchFocused ? 0.75 : 1)
            }
            Spacer()
            toolbarButtons
                .opacity(homeSearchFocused ? 0.45 : 1)
                .allowsHitTesting(!homeSearchFocused)
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var homeSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Tokens.Text.tertiary)
            TextField("Search sections and CTAs", text: $homeSearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($homeSearchFocused)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Tokens.Background.sunken)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(homeSearchFocused ? Tokens.Border.focus : Tokens.Border.default, lineWidth: 1)
                )
        )
        .accessibilityLabel("Search sections and CTAs")
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        HStack(spacing: 6) {
            AutosaveIndicator(
                isDirty: store.isSplashDirty,
                lastPersistedAt: store.lastDraftPersistedAt
            )

            RevealInFinderButton(
                url: RepoConstants.splashFile,
                helpText: "Reveal splash.json in Finder"
            )

            Button {
                showSourcePreview = true
            } label: {
                Image(systemName: "curlybraces")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Preview splash.json source")

            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Version history")

            Rectangle()
                .fill(Tokens.Border.subtle)
                .frame(width: 1, height: 14)
                .padding(.horizontal, 4)

            Button {
                slashController.activate()
            } label: {
                Label("Add section", systemImage: "plus")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.subtextAccent))
            .buttonStyle(.plain)
        }
    }
}
