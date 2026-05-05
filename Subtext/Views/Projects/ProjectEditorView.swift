import AppKit
import SwiftUI

struct ProjectEditorView: View {
    @Binding var document: ProjectDocument
    var onAddBlock: (_ insertAt: Int?) -> Void
    var onShowHistory: () -> Void

    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density
    @Environment(\.narrowLayout) private var narrowLayout
    @Environment(FocusModeController.self) private var focusMode
    @AppStorage("SubtextEditorUseMonospacedSourceFont") private var useMonospacedSourceFont = true
    @State private var slugManuallyEdited = false
    @State private var editorAreaHeight: CGFloat = 600
    @State private var showSourcePreview = false
    @State private var showAdvancedInspector = false
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var bodyEditorHeight: CGFloat = 260
    @State private var validationIssues: [ProjectValidationIssue] = []
    @State private var isValidating = false
    @State private var blockDrag = DragReorderState(spacing: 0)
    @State private var blockSearch = ""

    var body: some View {
        editorContent
    }

    @ViewBuilder
    private var editorContent: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !focusMode.isOn {
                        ProjectMetaHeader(
                            document: $document,
                            validationIssues: validationIssues,
                            isValidating: isValidating,
                            slugManuallyEdited: $slugManuallyEdited,
                            titleDerivedSlug: ProjectEditorView.slugify(document.frontmatter.title),
                            onSyncSlug: {
                                slugManuallyEdited = false
                                document.frontmatter.slug = ProjectEditorView.slugify(document.frontmatter.title)
                            },
                            onShowInspector: { showAdvancedInspector = true }
                        )
                        .padding(.horizontal, 40)
                    }

                    bodyEditor
                        .padding(.horizontal, 40)

                    if !focusMode.isOn {
                        blocksCanvas
                            .padding(.horizontal, 40)
                            .padding(.bottom, 80)
                    }
                }
                .padding(.top, 30)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                editorAreaHeight = h
            }
        }
        .sheet(isPresented: $showAdvancedInspector) {
            ProjectInspectorPanel(
                document: $document,
                validationIssues: validationIssues,
                isValidating: isValidating,
                slugManuallyEdited: slugManuallyEdited,
                titleDerivedSlug: ProjectEditorView.slugify(document.frontmatter.title),
                onSyncSlugFromTitle: {
                    slugManuallyEdited = false
                    document.frontmatter.slug = ProjectEditorView.slugify(document.frontmatter.title)
                }
            )
            .frame(minWidth: 360, minHeight: 500)
        }
        .modifier(ProjectEditorLifecycleModifier(
            document: $document,
            slugManuallyEdited: $slugManuallyEdited,
            validationIssues: $validationIssues,
            isValidating: $isValidating,
            store: store
        ))
        .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemUp)) { _ in
            moveSelectedBlock(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemDown)) { _ in
            moveSelectedBlock(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertBold)) { _ in
            insertInlineMarkdown(.bold)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertItalic)) { _ in
            insertInlineMarkdown(.italic)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertHeading)) { _ in
            insertMarkdownSnippet("## Heading")
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertLink)) { _ in
            insertInlineMarkdown(.link)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertInfoChip)) { _ in
            insertInlineMarkdown(.infoChip)
        }
    }

    private func moveSelectedBlock(by delta: Int) {
        guard let id = store.editingBlockID,
              let idx = document.frontmatter.blocks.firstIndex(where: { $0.id == id })
        else { return }
        let count = document.frontmatter.blocks.count
        let dest = max(0, min(count - 1, idx + delta))
        guard dest != idx else { return }
        let destination = delta > 0 ? dest + 1 : dest
        document.frontmatter.blocks.move(
            fromOffsets: IndexSet(integer: idx),
            toOffset: destination
        )
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 4) {
            // Group 1 — status (passive, left-aligned)
            AutosaveIndicator(
                isDirty: store.isProjectDirty(document.fileName),
                lastPersistedAt: store.lastDraftPersistedAt
            )
            .focusModeChrome()

            Spacer()

            // Group 2 — file actions (fade in focus mode)
            Group {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([projectFileURL])
                } label: {
                    Image(systemName: "folder")
                }
                .subtextButton(.icon)
                .help("Reveal \(document.fileName) in Finder")

                Button {
                    showSourcePreview = true
                } label: {
                    Image(systemName: "curlybraces")
                }
                .subtextButton(.icon)
                .help("Preview MDX source")

                Button { onShowHistory() } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .subtextButton(.icon)
                .help("Version history")

                toolbarDivider
            }
            .focusModeChrome()

            // Group 3 — view toggles (focus button always visible)
            Button { focusMode.toggle() } label: {
                Image(systemName: focusMode.isOn ? "rectangle.inset.filled.and.person.filled" : "rectangle.inset.filled")
                    .foregroundStyle(focusMode.isOn ? Color.subtextAccent : Tokens.Text.secondary)
                    .toggleBounce(trigger: focusMode.isOn)
            }
            .subtextButton(.icon)
            .help(focusMode.isOn ? "Disable focus mode" : "Enable focus mode")
            .contextMenu {
                Button {
                    focusMode.level = .reading
                    if !focusMode.isOn { focusMode.toggle() }
                } label: {
                    Label(
                        "Focus: Sidebar only",
                        systemImage: focusMode.level == .reading && focusMode.isOn ? "checkmark.circle.fill" : "sidebar.left"
                    )
                }
                Button {
                    focusMode.level = .writing
                    if !focusMode.isOn { focusMode.toggle() }
                } label: {
                    Label(
                        "Focus: Full (typewriter)",
                        systemImage: focusMode.level == .writing && focusMode.isOn ? "checkmark.circle.fill" : "person.fill"
                    )
                }
                Divider()
                Button {
                    if focusMode.isOn {
                        focusMode.cycleLevel()
                    } else {
                        focusMode.level = .writing
                        focusMode.toggle()
                    }
                } label: {
                    Label("Cycle focus level", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            toolbarDivider.focusModeChrome()

            // Group 4 — primary action
            Button {
                onAddBlock(nil)
            } label: {
                Label("Add block", systemImage: "plus")
            }
            .subtextButton(.primary)
            .focusModeChrome()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 10)
        .sheet(isPresented: $showSourcePreview) {
            SourcePreviewDrawer(source: .project(document)) {
                showSourcePreview = false
            }
        }
    }

    private var toolbarDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 4)
    }

    private var projectFileURL: URL {
        RepoConstants.projectsDirectory
            .appending(path: document.fileName, directoryHint: .notDirectory)
    }

    private var horizontalPadding: CGFloat {
        density == .compact ? 20 : 24
    }

    @ViewBuilder
    private var blocksCanvas: some View {
        @Bindable var store = store
        let blocks = document.frontmatter.blocks
        let filtered: [ProjectBlock] = blockSearch.isEmpty
            ? blocks
            : blocks.filter { block in
                block.kind.displayName.localizedCaseInsensitiveContains(blockSearch)
                || block.inlinePreview.localizedCaseInsensitiveContains(blockSearch)
            }
        let hasLayoutBlocks = filtered.contains { $0.isLayoutBlock }
        let hasContentBlocks = filtered.contains { !$0.isLayoutBlock }

        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Text("BLOCKS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .tracking(0.9)
                if blocks.count > 0 {
                    Text("\(blocks.count)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Tokens.Fill.tag))
                }
                if blocks.count > 1 {
                    Text("Drag or ⌘↑↓ to reorder")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                Spacer()
                if store.editingBlockID != nil {
                    Button("Collapse all") {
                        withAnimation(Motion.spring) { store.editingBlockID = nil }
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 12)

            if blocks.count > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.Text.tertiary)
                    TextField("Filter blocks…", text: $blockSearch)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !blockSearch.isEmpty {
                        Button { blockSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Tokens.Text.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Tokens.Background.sunken)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Tokens.Border.subtle, lineWidth: 1)
                        )
                )
                .padding(.bottom, 10)
            }

            if blocks.isEmpty {
                // Empty state — quick-add common blocks
                VStack(alignment: .leading, spacing: 10) {
                    Text("No blocks yet. Add one to get started:")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Text.tertiary)
                    HStack(spacing: 8) {
                        ForEach([ProjectBlock.Kind.pageHero, .keyStats, .quote, .cta], id: \.self) { kind in
                            Button {
                                let block = ProjectBlock.empty(of: kind)
                                document.frontmatter.blocks.append(block)
                                withAnimation(Motion.spring) { store.editingBlockID = block.id }
                            } label: {
                                Label(kind.displayName, systemImage: kind.systemImage)
                                    .font(.system(size: 11.5))
                            }
                            .subtextButton(.secondary)
                        }
                        Button {
                            onAddBlock(nil)
                        } label: {
                            Label("More…", systemImage: "ellipsis")
                                .font(.system(size: 11.5))
                        }
                        .subtextButton(.secondary)
                    }
                }
                .padding(.vertical, 16)
            } else if filtered.isEmpty {
                Text("No blocks match \"\(blockSearch)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .padding(.vertical, 16)
            } else {
                // Open flat list — top border only, no card wrapper
                Rectangle()
                    .fill(Tokens.Border.subtle)
                    .frame(height: 1)

                if blockSearch.isEmpty {
                    // Full list with drag-to-reorder
                    ReorderableVStack(
                        items: blocks,
                        spacing: 0,
                        dragState: blockDrag
                    ) { from, to in
                        document.frontmatter.blocks.move(fromOffsets: from, toOffset: to)
                    } row: { block, controls in
                        if let idx = document.frontmatter.blocks.firstIndex(where: { $0.id == block.id }) {
                            let listIdx = blocks.firstIndex(where: { $0.id == block.id }) ?? 0
                            let prevBlock: ProjectBlock? = listIdx > 0 ? blocks[listIdx - 1] : nil
                            let showGroupHeader = hasLayoutBlocks && hasContentBlocks
                                && listIdx > 0
                                && prevBlock?.isLayoutBlock != block.isLayoutBlock

                            VStack(spacing: 0) {
                                if showGroupHeader {
                                    groupDivider(isLayout: block.isLayoutBlock)
                                }
                                BlockRowView(
                                    block: $document.frontmatter.blocks[idx],
                                    isExpanded: store.editingBlockID == block.id,
                                    reorderControls: controls,
                                    onToggleExpand: {
                                        withAnimation(Motion.spring) {
                                            store.editingBlockID = store.editingBlockID == block.id ? nil : block.id
                                        }
                                    },
                                    onDelete: { deleteBlock(block) },
                                    onDuplicate: { duplicateBlock(block) },
                                    onInsertBelow: { onAddBlock(idx + 1) }
                                )
                            }
                        }
                    }
                } else {
                    // Filtered list — no drag reorder
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { filteredIdx, block in
                            if let idx = document.frontmatter.blocks.firstIndex(where: { $0.id == block.id }) {
                                let prevBlock: ProjectBlock? = filteredIdx > 0 ? filtered[filteredIdx - 1] : nil
                                let showGroupHeader = hasLayoutBlocks && hasContentBlocks
                                    && filteredIdx > 0
                                    && prevBlock?.isLayoutBlock != block.isLayoutBlock

                                VStack(spacing: 0) {
                                    if showGroupHeader {
                                        groupDivider(isLayout: block.isLayoutBlock)
                                    }
                                    BlockRowView(
                                        block: $document.frontmatter.blocks[idx],
                                        isExpanded: store.editingBlockID == block.id,
                                        onToggleExpand: {
                                            withAnimation(Motion.spring) {
                                                store.editingBlockID = store.editingBlockID == block.id ? nil : block.id
                                            }
                                        },
                                        onDelete: { deleteBlock(block) },
                                        onDuplicate: { duplicateBlock(block) },
                                        onInsertBelow: { onAddBlock(idx + 1) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Minimal formatting bar
            HStack(alignment: .center, spacing: 1) {
                Text("BODY")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .tracking(0.9)
                    .padding(.trailing, 8)

                MarkdownInsertToolbar(text: $document.body, selection: $bodySelection)

                Spacer()

                Button {
                    NotificationCenter.default.post(name: .subtextMarkdownShowReplace, object: nil)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Find & Replace (⌘⌥F)")
                .keyboardShortcut("f", modifiers: [.command, .option])

                Menu {
                    Toggle("Monospaced source font", isOn: $useMonospacedSourceFont)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .help("Editor display options")
                .accessibilityLabel("Editor display options")
            }
            .padding(.bottom, 10)

            Rectangle()
                .fill(Tokens.Border.subtle)
                .frame(height: 1)
                .padding(.bottom, 16)

            if focusMode.isOn {
                Label("Focus mode — only the body editor is visible.", systemImage: "rectangle.inset.filled")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
                    .padding(.bottom, 8)
            }

            sourceEditor

            if !focusMode.isOn {
                bodyWordCountLabel
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, focusMode.isOn ? 0 : 28)
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var bodyWordCountLabel: some View {
        let words = document.body
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        let minutes = max(1, words / 200)
        return Text(words == 0 ? "No content yet" : "\(words) words · ~\(minutes) min read")
            .font(.system(size: 10))
            .foregroundStyle(Tokens.Text.tertiary)
    }

    private var sourceEditor: some View {
        let typewriterHeight = focusMode.isOn ? editorAreaHeight : nil
        return MarkdownSourceEditor(
            text: $document.body,
            selection: $bodySelection,
            font: nsSourceFont,
            contentHeight: focusMode.isOn ? nil : $bodyEditorHeight,
            typewriterHeight: typewriterHeight
        )
        .frame(height: typewriterHeight ?? bodyEditorHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.large, style: .continuous))
        .accessibilityLabel("Markdown source editor")
    }


    private var nsSourceFont: NSFont {
        let size = NSFont.systemFontSize + 1
        return useMonospacedSourceFont
            ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            : NSFont.systemFont(ofSize: size)
    }

    @ViewBuilder
    private func groupDivider(isLayout: Bool) -> some View {
        HStack(spacing: 6) {
            Text(isLayout ? "LAYOUT" : "CONTENT")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Tokens.Text.tertiary)
                .tracking(0.8)
            Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }

    private func duplicateBlock(_ block: ProjectBlock) {
        guard let idx = document.frontmatter.blocks.firstIndex(where: { $0.id == block.id }) else { return }
        let copy = block.duplicated()
        document.frontmatter.blocks.insert(copy, at: idx + 1)
        withAnimation(Motion.spring) {
            store.editingBlockID = copy.id
        }
    }

    private func deleteBlock(_ block: ProjectBlock) {
        guard let idx = document.frontmatter.blocks.firstIndex(where: { $0.id == block.id }) else { return }
        let removed = document.frontmatter.blocks.remove(at: idx)
        if store.editingBlockID == removed.id { store.editingBlockID = nil }
        store.offerUndo(label: "Deleted \(removed.kind.displayName) block") {
            var blocks = document.frontmatter.blocks
            let safeIdx = min(idx, blocks.count)
            blocks.insert(removed, at: safeIdx)
            document.frontmatter.blocks = blocks
        }
    }

    private func insertMarkdownSnippet(_ snippet: String) {
        let nsText = document.body as NSString
        let length = nsText.length
        let location = max(0, min(bodySelection.location, length))
        let span = max(0, min(bodySelection.length, length - location))
        let range = NSRange(location: location, length: span)

        let needsLeading: Bool = {
            if location == 0 { return false }
            return nsText.substring(with: NSRange(location: location - 1, length: 1)) != "\n"
        }()
        let needsTrailing: Bool = {
            if location + span >= length { return false }
            return nsText.substring(with: NSRange(location: location + span, length: 1)) != "\n"
        }()
        let composed = (needsLeading ? "\n" : "") + snippet + (needsTrailing ? "\n" : "")
        document.body = nsText.replacingCharacters(in: range, with: composed)

        let caret = location + (composed as NSString).length
        bodySelection = NSRange(location: caret, length: 0)
    }

    private func insertInlineMarkdown(_ style: MarkdownInlineFormatter.Style) {
        let result = MarkdownInlineFormatter.apply(
            style: style,
            to: document.body,
            selection: bodySelection
        )
        document.body = result.text
        bodySelection = result.selection
    }

    static func slugify(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

}

private struct ProjectEditorLifecycleModifier: ViewModifier {
    @Binding var document: ProjectDocument
    @Binding var slugManuallyEdited: Bool
    @Binding var validationIssues: [ProjectValidationIssue]
    @Binding var isValidating: Bool
    let store: CMSStore
    @State private var validationTask: Task<Void, Never>?
    private let validationClock = ContinuousClock()

    func body(content: Content) -> some View {
        content
            .onChange(of: document.frontmatter.title) { _, title in
                guard !slugManuallyEdited else { return }
                document.frontmatter.slug = ProjectEditorView.slugify(title)
            }
            .onChange(of: document.frontmatter.slug) { oldValue, newValue in
                let autoSlug = ProjectEditorView.slugify(document.frontmatter.title)
                let didBecomeCustom = !newValue.isEmpty
                    && newValue != autoSlug
                    && newValue != oldValue
                if didBecomeCustom {
                    slugManuallyEdited = true
                }
            }
            .onChange(of: document) { _, updated in
                scheduleValidation(for: updated)
            }
            .onAppear {
                validationIssues = ProjectValidator.validate(document)
                isValidating = false
            }
            .onDisappear {
                validationTask?.cancel()
                validationTask = nil
                isValidating = false
            }
    }

    private func scheduleValidation(for updated: ProjectDocument) {
        if validationTask != nil {
            store.recordUXEvent("validation.coalesce.cancelled", metadata: updated.fileName)
        }
        validationTask?.cancel()
        let debounceNanos: UInt64 = updated.body.count > 8_000 ? 180_000_000 : 70_000_000
        isValidating = true
        let started = validationClock.now
        validationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled else {
                isValidating = false
                return
            }
            validationIssues = ProjectValidator.validate(updated)
            isValidating = false
            let elapsed = validationClock.now - started
            let elapsedMs = elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000
            store.recordUXEvent(
                "validation.coalesce.completed",
                metadata: "\(updated.fileName) \(elapsedMs)ms issues=\(validationIssues.count)"
            )
        }
    }
}

