import AppKit
import SwiftUI

struct ProjectEditorView: View {
    @Binding var document: ProjectDocument
    var onAddBlock: () -> Void
    var onShowHistory: () -> Void

    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density
    @AppStorage("SubtextEditorUseMonospacedSourceFont") private var useMonospacedSourceFont = true
    @AppStorage("SubtextProjectFocusModeEnabled") private var focusModeEnabled = false
    @State private var slugManuallyEdited = false
    @State private var showSourcePreview = false
    @State private var inspectorVisible = true
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var validationIssues: [ProjectValidationIssue] = []
    @State private var isValidating = false

    var body: some View {
        editorContent
    }

    @ViewBuilder
    private var editorContent: some View {
        HStack(spacing: 0) {
            // Main canvas — sticky toolbar + scrollable content
            VStack(spacing: 0) {
                toolbar
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: density.sectionOuterSpacing) {
                        if !focusModeEnabled {
                            blocksCanvas
                                .padding(.horizontal, horizontalPadding)
                        }

                        bodyEditor
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 80)
                    }
                    .padding(.top, density.canvasTopPadding)
                }
            }

            // Inspector panel — frontmatter fields
            if inspectorVisible && !focusModeEnabled {
                Divider()
                ProjectInspectorPanel(
                    document: $document,
                    validationIssues: validationIssues,
                    isValidating: isValidating,
                    slugManuallyEdited: slugManuallyEdited
                )
                .frame(width: 280)
            }
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

            Spacer()

            // Group 2 — file actions
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

            // Group 3 — view toggles
            Button { focusModeEnabled.toggle() } label: {
                Image(systemName: focusModeEnabled ? "rectangle.inset.filled.and.person.filled" : "rectangle.inset.filled")
                    .foregroundStyle(focusModeEnabled ? Color.subtextAccent : Tokens.Text.secondary)
            }
            .subtextButton(.icon)
            .help(focusModeEnabled ? "Disable focus mode" : "Enable focus mode")

            Button { inspectorVisible.toggle() } label: {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(inspectorVisible ? Color.subtextAccent : Tokens.Text.secondary)
            }
            .subtextButton(.icon)
            .help(inspectorVisible ? "Hide inspector" : "Show inspector")

            toolbarDivider

            // Group 4 — primary action
            Button {
                onAddBlock()
            } label: {
                Label("Add block", systemImage: "plus")
            }
            .subtextButton(.primary)
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
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Text("Blocks")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Tokens.Text.primary)
                if document.frontmatter.blocks.count > 0 {
                    Text("\(document.frontmatter.blocks.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.subtextSubtleFill))
                }
                if document.frontmatter.blocks.count > 1 {
                    Text("⌘↑↓ to reorder")
                        .font(.caption2)
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                Spacer()
            }
            .padding(.bottom, 10)

            if document.frontmatter.blocks.isEmpty {
                // Minimal empty state — text button, no dashed border
                Button(action: onAddBlock) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13, weight: .medium))
                        Text("Add your first block")
                            .font(.callout)
                    }
                    .foregroundStyle(Tokens.Accent.subtleText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add first block")
            } else {
                // Block list with divider separators instead of spacing
                Surface(.surface) {
                    ReorderableVStack(
                        items: document.frontmatter.blocks,
                        spacing: 0
                    ) { from, to in
                        document.frontmatter.blocks.move(fromOffsets: from, toOffset: to)
                    } row: { block, controls in
                        VStack(spacing: 0) {
                            if block.id != document.frontmatter.blocks.first?.id {
                                Divider().padding(.leading, 14)
                            }
                            BlockCardView(
                                block: block,
                                reorderControls: controls,
                                onEdit: { store.editingBlockID = block.id },
                                onDelete: { deleteBlock(block) }
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var bodyEditor: some View {
        Surface(.surface) {
            VStack(alignment: .leading, spacing: SubtextUI.Spacing.small + 2) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Body (markdown)")
                        .font(SubtextUI.Typography.sectionTitle)

                    Spacer()

                    Menu {
                        Toggle("Monospaced source font", isOn: $useMonospacedSourceFont)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Editor display options")
                    .accessibilityLabel("Editor display options")

                    MarkdownInsertToolbar(text: $document.body, selection: $bodySelection)
                }

                if focusModeEnabled {
                    Label("Focus mode keeps only the body editor visible. Use the inset toggle in the toolbar to restore panels.", systemImage: "rectangle.inset.filled")
                        .font(SubtextUI.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Focus mode enabled. Only body editor is visible.")
                        .accessibilityHint("Use the focus mode toolbar button to restore frontmatter and block panels.")
                }

                sourceEditor
            }
        }
        .padding(SubtextUI.Spacing.large)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var sourceEditor: some View {
        MarkdownSourceEditor(
            text: $document.body,
            selection: $bodySelection,
            font: nsSourceFont
        )
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.large, style: .continuous))
        .accessibilityLabel("Markdown source editor")
    }


    private var nsSourceFont: NSFont {
        let size = NSFont.systemFontSize + 1
        return useMonospacedSourceFont
            ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            : NSFont.systemFont(ofSize: size)
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

    fileprivate static func slugify(_ s: String) -> String {
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

