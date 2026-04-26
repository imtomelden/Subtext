import SwiftUI

struct ProjectEditorView: View {
    @Binding var document: ProjectDocument
    var onBack: () -> Void
    var onAddBlock: () -> Void
    var onShowHistory: () -> Void

    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density
    @AppStorage("SubtextProjectLiveMarkdownPreviewEnabled") private var liveMarkdownEnabled = true
    @AppStorage("SubtextEditorUseMonospacedSourceFont") private var useMonospacedSourceFont = true
    @AppStorage("SubtextEditorPreviewLineSpacing") private var previewLineSpacing = 4.0
    @State private var frontmatterExpanded = true
    @State private var advancedExpanded = false
    @State private var videoMetaExpanded = false
    @State private var slugManuallyEdited = false
    @State private var draggingBlockID: UUID?
    @State private var showSourcePreview = false
    @State private var editorMode: EditorMode = .split

    private enum EditorMode: String, CaseIterable, Identifiable {
        case edit
        case split
        case preview

        var id: String { rawValue }

        var label: String {
            switch self {
            case .edit: "Edit"
            case .split: "Split"
            case .preview: "Preview"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: density.sectionOuterSpacing) {
                toolbar
                frontmatterPanel
                    .padding(.horizontal, horizontalPadding)

                blocksCanvas
                    .padding(.horizontal, horizontalPadding)

                bodyEditor
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 80)
            }
            .padding(.top, density.canvasTopPadding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemUp)) { _ in
            moveSelectedBlock(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextMoveItemDown)) { _ in
            moveSelectedBlock(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertBold)) { _ in
            insertMarkdownSnippet("**bold**")
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertItalic)) { _ in
            insertMarkdownSnippet("*italic*")
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertHeading)) { _ in
            insertMarkdownSnippet("## Heading")
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectInsertLink)) { _ in
            insertMarkdownSnippet("[link text](https://)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextProjectTogglePreviewMode)) { _ in
            cycleEditorMode()
        }
        .onChange(of: liveMarkdownEnabled) { _, enabled in
            if !enabled {
                editorMode = .edit
            } else if editorMode == .edit {
                editorMode = .split
            }
        }
        .onChange(of: document.frontmatter.title) { _, title in
            guard !slugManuallyEdited else { return }
            document.frontmatter.slug = Self.slugify(title)
        }
        .onChange(of: document.frontmatter.slug) { oldValue, newValue in
            if !newValue.isEmpty && newValue != Self.slugify(document.frontmatter.title) && newValue != oldValue {
                slugManuallyEdited = true
            }
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
        HStack {
            Button {
                onBack()
            } label: {
                Label("Projects", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 10) {
                RevealInFinderButton(
                    url: projectFileURL,
                    helpText: "Reveal \(document.fileName) in Finder"
                )

                Button {
                    showSourcePreview = true
                } label: {
                    Image(systemName: "curlybraces")
                }
                .help("Preview MDX source")
                .accessibilityLabel("Preview source")
                .buttonStyle(.bordered)

                Button {
                    onShowHistory()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .help("Version history")
                .accessibilityLabel("Version history")
                .buttonStyle(.bordered)

                Button {
                    onAddBlock()
                } label: {
                    Label("Add block", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.subtextAccent)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .sheet(isPresented: $showSourcePreview) {
            SourcePreviewDrawer(source: .project(document)) {
                showSourcePreview = false
            }
        }
    }

    private var projectFileURL: URL {
        RepoConstants.projectsDirectory
            .appending(path: document.fileName, directoryHint: .notDirectory)
    }

    private var horizontalPadding: CGFloat {
        density == .compact ? 20 : 28
    }

    private var validationIssues: [ProjectValidationIssue] {
        ProjectValidator.validate(document)
    }

    @ViewBuilder
    private var frontmatterPanel: some View {
        GlassSurface(prominence: .interactive, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        frontmatterExpanded.toggle()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.frontmatter.title.isEmpty ? "Untitled project" : document.frontmatter.title)
                                .font(.title2.weight(.semibold))
                            Text(document.fileName)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(frontmatterExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                }
                .buttonStyle(.plain)

                if frontmatterExpanded {
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        if !validationIssues.isEmpty {
                            validationBanner
                        }
                        frontmatterFields
                    }
                    .padding(20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private var frontmatterFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Essentials")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 14) {
                FieldRow("Title") {
                    TextField("Title", text: $document.frontmatter.title)
                        .textFieldStyle(.roundedBorder)
                }

                FieldRow("Ownership") {
                    Picker("Ownership", selection: $document.frontmatter.ownership) {
                        ForEach(ProjectFrontmatter.Ownership.allCases) { ownership in
                            Text(ownership.displayName).tag(ownership)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            FieldRow("Description") {
                TextField("Short description", text: $document.frontmatter.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            FieldRow("Date") {
                DateField(value: $document.frontmatter.date)
            }
            .frame(maxWidth: 220)

            FieldRow("Tags") {
                TagEditor(tags: $document.frontmatter.tags)
            }

            DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        FieldRow("Slug") {
                            TextField("kebab-case-slug", text: $document.frontmatter.slug)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(maxWidth: 260)

                        if !slugManuallyEdited {
                            Text("Auto-generated from title")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    FieldRow("Thumbnail") {
                        AssetPathField(path: optionalBinding(\.thumbnail))
                    }

                    FieldRow("Header image") {
                        AssetPathField(path: optionalBinding(\.headerImage))
                    }

                    FieldRow("External URL") {
                        TextField("https://… (optional)", text: optionalBinding(\.externalUrl))
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 20) {
                        Toggle(isOn: $document.frontmatter.featured) {
                            Label("Featured", systemImage: "star.fill")
                        }
                        .toggleStyle(.switch)
                        .tint(Color.subtextAccent)

                        Toggle(isOn: $document.frontmatter.draft) {
                            Label("Draft", systemImage: "pencil.and.list.clipboard")
                        }
                        .toggleStyle(.switch)
                        .tint(.orange)
                    }
                }
                .padding(.top, 8)
            }

            if document.frontmatter.tags.contains(where: { $0.caseInsensitiveCompare("video") == .orderedSame }) {
                DisclosureGroup("Video metadata", isExpanded: $videoMetaExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        FieldRow("Runtime") {
                            TextField("e.g. 3m 45s", text: optionalVideoMetaBinding(\.runtime))
                                .textFieldStyle(.roundedBorder)
                        }
                        FieldRow("Platform") {
                            TextField("YouTube, Vimeo, Website player…", text: optionalVideoMetaBinding(\.platform))
                                .textFieldStyle(.roundedBorder)
                        }
                        FieldRow("Transcript URL") {
                            TextField("https://... (optional)", text: optionalVideoMetaBinding(\.transcriptUrl))
                                .textFieldStyle(.roundedBorder)
                        }
                        FieldRow("Credits") {
                            StringListEditor(
                                items: videoMetaCreditsBinding,
                                placeholder: "Credit entry",
                                addLabel: "Add credit",
                                showReorderControls: true
                            )
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var blocksCanvas: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Blocks")
                        .font(.title3.weight(.semibold))
                    Text("\(document.frontmatter.blocks.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.quaternary.opacity(0.4), in: Capsule())
                }
                if document.frontmatter.blocks.count > 1 {
                    Label("Drag to reorder", systemImage: "line.3.horizontal")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            if document.frontmatter.blocks.isEmpty {
                VStack(spacing: 6) {
                    Text("No blocks yet").font(.callout.weight(.medium))
                    Text("Add your first block using the toolbar button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            } else {
                ForEach(document.frontmatter.blocks) { block in
                    BlockCardView(block: block) {
                        store.editingBlockID = block.id
                    } onDelete: {
                        deleteBlock(block)
                    }
                    .onDrag {
                        draggingBlockID = block.id
                        return NSItemProvider(object: block.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: BlockDropDelegate(
                            targetID: block.id,
                            draggingID: $draggingBlockID,
                            blocks: $document.frontmatter.blocks
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Body (markdown)")
                    .font(.title3.weight(.semibold))

                Spacer()

                if liveMarkdownEnabled {
                    Picker("Editor mode", selection: $editorMode) {
                        ForEach(EditorMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                    .help("Switch between editing, split, and live preview")
                }

                Menu {
                    Toggle("Monospaced source font", isOn: $useMonospacedSourceFont)
                    if liveMarkdownEnabled {
                        Divider()
                        Picker("Preview line spacing", selection: $previewLineSpacing) {
                            Text("Tight").tag(2.0)
                            Text("Default").tag(4.0)
                            Text("Relaxed").tag(6.0)
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .menuStyle(.borderlessButton)
                .help("Editor display options")

                MarkdownInsertToolbar(text: $document.body)
            }

            if liveMarkdownEnabled {
                HStack(alignment: .top, spacing: 12) {
                    if editorMode != .preview {
                        sourceEditor
                    }
                    if editorMode != .edit {
                        LiveMarkdownPreview(
                            markdown: document.body,
                            lineSpacing: previewLineSpacing
                        )
                        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
                    }
                }
            } else {
                sourceEditor
            }
        }
    }

    private var sourceEditor: some View {
        TextEditor(text: $document.body)
            .font(sourceFont)
            .scrollContentBackground(.hidden)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
            .background(
                GlassSurface(prominence: .interactive, cornerRadius: 12) { Color.clear }
            )
            .accessibilityLabel("Markdown source editor")
    }

    private var sourceFont: Font {
        useMonospacedSourceFont ? .body.monospaced() : .body
    }

    @ViewBuilder
    private var validationBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Required fields need attention before save.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(Array(validationIssues.prefix(5).enumerated()), id: \.offset) { _, issue in
                Text("• \(issue.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func optionalBinding(_ keyPath: WritableKeyPath<ProjectFrontmatter, String?>) -> Binding<String> {
        Binding(
            get: { document.frontmatter[keyPath: keyPath] ?? "" },
            set: { document.frontmatter[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private var videoMetaCreditsBinding: Binding<[String]> {
        Binding(
            get: { document.frontmatter.videoMeta?.credits ?? [] },
            set: { newValue in
                var meta = document.frontmatter.videoMeta ?? .init(
                    runtime: nil,
                    platform: nil,
                    transcriptUrl: nil,
                    credits: []
                )
                meta.credits = newValue
                document.frontmatter.videoMeta = meta.isEmpty ? nil : meta
            }
        )
    }

    private func optionalVideoMetaBinding(_ keyPath: WritableKeyPath<ProjectFrontmatter.VideoMeta, String?>) -> Binding<String> {
        Binding(
            get: { document.frontmatter.videoMeta?[keyPath: keyPath] ?? "" },
            set: { newValue in
                var meta = document.frontmatter.videoMeta ?? .init(
                    runtime: nil,
                    platform: nil,
                    transcriptUrl: nil,
                    credits: []
                )
                meta[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                document.frontmatter.videoMeta = meta.isEmpty ? nil : meta
            }
        )
    }

    private func insertMarkdownSnippet(_ snippet: String) {
        if !document.body.hasSuffix("\n") && !document.body.isEmpty {
            document.body += "\n"
        }
        document.body += "\n\(snippet)\n"
    }

    private func cycleEditorMode() {
        guard liveMarkdownEnabled else { return }
        switch editorMode {
        case .edit:
            editorMode = .split
        case .split:
            editorMode = .preview
        case .preview:
            editorMode = .edit
        }
    }

    private static func slugify(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

}

private struct BlockDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    @Binding var blocks: [ProjectBlock]

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        guard let from = blocks.firstIndex(where: { $0.id == draggingID }) else { return }
        guard let to = blocks.firstIndex(where: { $0.id == targetID }) else { return }
        if from != to {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                blocks.move(fromOffsets: IndexSet(integer: from), toOffset: from < to ? to + 1 : to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

/// Renders markdown as the user types, with a small debounce so large
/// documents stay responsive while still feeling immediate.
private struct LiveMarkdownPreview: View {
    let markdown: String
    let lineSpacing: CGFloat

    @State private var rendered = AttributedString("")
    @State private var renderError: String?
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let renderError {
                    Label(renderError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if rendered.characters.isEmpty && markdown.isEmpty {
                    Text("Start typing markdown to see a live preview.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(rendered)
                        .lineSpacing(lineSpacing)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
        .background(
            GlassSurface(prominence: .interactive, cornerRadius: 12) { Color.clear }
        )
        .task { scheduleRender(for: markdown) }
        .onChange(of: markdown) { _, updated in
            scheduleRender(for: updated)
        }
        .onDisappear {
            renderTask?.cancel()
            renderTask = nil
        }
    }

    private func scheduleRender(for text: String) {
        renderTask?.cancel()
        let debounceNanos: UInt64 = text.count > 7_500 ? 180_000_000 : 50_000_000
        renderTask = Task {
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                render(text)
            }
        }
    }

    private func render(_ text: String) {
        do {
            rendered = try AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .full)
            )
            renderError = nil
        } catch {
            rendered = AttributedString(text)
            renderError = "Some markdown could not be parsed. Showing plain text until syntax is fixed."
        }
    }
}
