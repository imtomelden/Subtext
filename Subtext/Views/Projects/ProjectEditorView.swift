import AppKit
import OSLog
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
    @AppStorage("SubtextProjectFocusModeEnabled") private var focusModeEnabled = false
    @State private var frontmatterExpanded = true
    @State private var advancedExpanded = false
    @State private var videoMetaExpanded = false
    @State private var caseStudyExpanded = false
    @State private var heroExpanded = false
    @State private var didLoadDisclosureState = false
    @State private var slugManuallyEdited = false
    @State private var showSourcePreview = false
    @State private var editorMode: EditorMode = .split
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var validationIssues: [ProjectValidationIssue] = []
    @State private var isValidating = false

    fileprivate enum EditorMode: String, CaseIterable, Identifiable {
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
        editorContent
    }

    @ViewBuilder
    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: density.sectionOuterSpacing) {
                toolbar
                if !focusModeEnabled {
                    frontmatterPanel
                        .padding(.horizontal, horizontalPadding)

                    blocksCanvas
                        .padding(.horizontal, horizontalPadding)
                }

                bodyEditor
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 80)
            }
            .padding(.top, density.canvasTopPadding)
        }
        .modifier(ProjectEditorLifecycleModifier(
            liveMarkdownEnabled: liveMarkdownEnabled,
            editorMode: $editorMode,
            document: $document,
            slugManuallyEdited: $slugManuallyEdited,
            advancedExpanded: $advancedExpanded,
            videoMetaExpanded: $videoMetaExpanded,
            caseStudyExpanded: $caseStudyExpanded,
            heroExpanded: $heroExpanded,
            didLoadDisclosureState: $didLoadDisclosureState,
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
        GlassSurface(prominence: .regular, cornerRadius: SubtextUI.Radius.xLarge) {
            HStack(spacing: SubtextUI.Spacing.medium) {
                Button {
                    onBack()
                } label: {
                    Label("Projects", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Back to projects list")

                Spacer()

                HStack(spacing: SubtextUI.Spacing.small) {
                    AutosaveIndicator(
                        isDirty: store.isProjectDirty(document.fileName),
                        lastPersistedAt: store.lastDraftPersistedAt
                    )

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
                    .controlSize(.small)

                    Button {
                        onShowHistory()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .help("Version history")
                    .accessibilityLabel("Version history")
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            focusModeEnabled.toggle()
                        }
                    } label: {
                        Image(systemName: focusModeEnabled ? "rectangle.inset.filled.and.person.filled" : "rectangle.inset.filled")
                    }
                    .help(focusModeEnabled ? "Disable focus mode" : "Enable focus mode")
                    .accessibilityLabel(focusModeEnabled ? "Disable focus mode" : "Enable focus mode")
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(focusModeEnabled ? Color.subtextAccent : nil)

                    Button {
                        onAddBlock()
                    } label: {
                        Label("Add block", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.subtextAccent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, SubtextUI.Spacing.large)
            .padding(.vertical, SubtextUI.Spacing.medium)
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

    @ViewBuilder
    private var frontmatterPanel: some View {
        GlassSurface(prominence: .interactive, cornerRadius: SubtextUI.Radius.xLarge) {
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
                        if !validationIssues.isEmpty {
                            collapsedValidationChip
                        }
                        if isValidating {
                            validatingChip
                        }
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(frontmatterExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                    }
                    .padding(SubtextUI.Spacing.large + 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Project frontmatter")
                .accessibilityValue(frontmatterExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Shows required metadata fields before saving.")

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
        .frame(maxWidth: 1_050, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Compact indicator surfaced in the collapsed frontmatter header so users
    /// can see at a glance that there are still required fields to fix without
    /// expanding the full panel.
    @ViewBuilder
    private var collapsedValidationChip: some View {
        let count = validationIssues.count
        Label("\(count) to fix", systemImage: "exclamationmark.triangle.fill")
            .labelStyle(.titleAndIcon)
            .font(SubtextUI.Typography.labelStrong)
            .foregroundStyle(Color.subtextWarning)
            .padding(.horizontal, SubtextUI.Spacing.small)
            .padding(.vertical, SubtextUI.Spacing.xSmall - 1)
            .background(
                Capsule().fill(SubtextUI.Surface.warningFill)
            )
            .help(validationIssues.prefix(5).map { $0.message }.joined(separator: "\n"))
            .accessibilityLabel("\(count) validation issue\(count == 1 ? "" : "s")")
    }

    @ViewBuilder
    private var validatingChip: some View {
        Label("Validating", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            .labelStyle(.titleAndIcon)
            .font(SubtextUI.Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, SubtextUI.Spacing.small)
            .padding(.vertical, SubtextUI.Spacing.xSmall - 1)
            .background(
                Capsule().fill(SubtextUI.Surface.subtleFill)
            )
            .accessibilityLabel("Validation in progress")
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
                    .accessibilityLabel("Ownership")
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
                        .tint(Color.subtextWarning)
                    }
                }
                .padding(.top, 8)
            }
            .accessibilityLabel("Advanced project metadata")
            .accessibilityValue(advancedExpanded ? "Expanded" : "Collapsed")

            DisclosureGroup("Case study", isExpanded: $caseStudyExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        FieldRow("Role") {
                            TextField("e.g. Lead designer", text: optionalBinding(\.role))
                                .textFieldStyle(.roundedBorder)
                        }
                        FieldRow("Duration") {
                            TextField("e.g. 3 months", text: optionalBinding(\.duration))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    FieldRow("Impact") {
                        TextField("Headline outcome (one line)", text: optionalBinding(\.impact), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...3)
                    }

                    FieldRow("Challenge") {
                        TextField("What problem this project addressed", text: optionalBinding(\.challenge), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    FieldRow("Approach") {
                        TextField("How you tackled it", text: optionalBinding(\.approach), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    FieldRow("Outcome") {
                        TextField("What shipped, what changed", text: optionalBinding(\.outcome), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }
                .padding(.top, 8)
            }
            .accessibilityLabel("Case study details")
            .accessibilityValue(caseStudyExpanded ? "Expanded" : "Collapsed")

            DisclosureGroup("Hero", isExpanded: $heroExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optional override for the project's hero block. Leave empty to fall back to the title and description.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FieldRow("Eyebrow") {
                        TextField("Small label above title", text: heroBinding(\.eyebrow))
                            .textFieldStyle(.roundedBorder)
                    }
                    FieldRow("Title") {
                        TextField("Hero title (overrides project title)", text: heroBinding(\.title))
                            .textFieldStyle(.roundedBorder)
                    }
                    FieldRow("Subtitle") {
                        TextField("Hero subtitle", text: heroBinding(\.subtitle), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...3)
                    }
                }
                .padding(.top, 8)
            }
            .accessibilityLabel("Hero override")
            .accessibilityValue(heroExpanded ? "Expanded" : "Collapsed")

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
                .accessibilityLabel("Video metadata")
                .accessibilityValue(videoMetaExpanded ? "Expanded" : "Collapsed")
            }
        }
    }

    @ViewBuilder
    private var blocksCanvas: some View {
        GlassSurface(prominence: .regular, cornerRadius: SubtextUI.Radius.xLarge) {
            VStack(alignment: .leading, spacing: SubtextUI.Spacing.small + 2) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Blocks")
                            .font(SubtextUI.Typography.sectionTitle)
                        Text("\(document.frontmatter.blocks.count)")
                            .font(SubtextUI.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(SubtextUI.Surface.subtleFill, in: Capsule())
                    }
                    if document.frontmatter.blocks.count > 1 {
                        Label("Use chevrons or ⌘↑/⌘↓ to reorder", systemImage: "chevron.up.chevron.down")
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
                        RoundedRectangle(cornerRadius: SubtextUI.Radius.large, style: .continuous)
                            .strokeBorder(SubtextUI.Surface.dashedStroke, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("No blocks yet")
                    .accessibilityHint("Use Add block in the toolbar to insert your first block.")
                } else {
                    ReorderableVStack(
                        items: document.frontmatter.blocks,
                        spacing: 10
                    ) { from, to in
                        document.frontmatter.blocks.move(fromOffsets: from, toOffset: to)
                    } row: { block, controls in
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
        .padding(SubtextUI.Spacing.large)
        .frame(maxWidth: 1_050, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var bodyEditor: some View {
        GlassSurface(prominence: .regular, cornerRadius: SubtextUI.Radius.xLarge) {
            VStack(alignment: .leading, spacing: SubtextUI.Spacing.small + 2) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Body (markdown)")
                        .font(SubtextUI.Typography.sectionTitle)

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
                        .accessibilityLabel("Editor mode")
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

                if liveMarkdownEnabled {
                    HStack(alignment: .top, spacing: SubtextUI.Spacing.medium) {
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
        .padding(SubtextUI.Spacing.large)
        .frame(maxWidth: 1_050, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var sourceEditor: some View {
        MarkdownSourceEditor(
            text: $document.body,
            selection: $bodySelection,
            font: nsSourceFont
        )
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(
            GlassSurface(prominence: .interactive, cornerRadius: SubtextUI.Radius.large) { Color.clear }
        )
        .clipShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.large, style: .continuous))
        .accessibilityLabel("Markdown source editor")
    }

    private var sourceFont: Font {
        useMonospacedSourceFont ? .body.monospaced() : .body
    }

    private var nsSourceFont: NSFont {
        let size = NSFont.systemFontSize
        return useMonospacedSourceFont
            ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            : NSFont.systemFont(ofSize: size)
    }

    @ViewBuilder
    private var validationBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Required fields need attention before save.", systemImage: "exclamationmark.triangle.fill")
                .font(SubtextUI.Typography.labelStrong)
                .foregroundStyle(Color.subtextWarning)
            ForEach(Array(validationIssues.prefix(5).enumerated()), id: \.offset) { _, issue in
                Text("• \(issue.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(SubtextUI.Surface.warningBannerFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.medium, style: .continuous))
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

    /// Materialise the optional `hero` struct on first edit and clear it back to
    /// `nil` when every sub-field is empty so the YAML stays clean.
    private func heroBinding(_ keyPath: WritableKeyPath<ProjectFrontmatter.Hero, String?>) -> Binding<String> {
        Binding(
            get: { document.frontmatter.hero?[keyPath: keyPath] ?? "" },
            set: { newValue in
                var hero = document.frontmatter.hero ?? .init(eyebrow: nil, title: nil, subtitle: nil)
                hero[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                document.frontmatter.hero = hero.isEmpty ? nil : hero
            }
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
    let liveMarkdownEnabled: Bool
    @Binding var editorMode: ProjectEditorView.EditorMode
    @Binding var document: ProjectDocument
    @Binding var slugManuallyEdited: Bool
    @Binding var advancedExpanded: Bool
    @Binding var videoMetaExpanded: Bool
    @Binding var caseStudyExpanded: Bool
    @Binding var heroExpanded: Bool
    @Binding var didLoadDisclosureState: Bool
    @Binding var validationIssues: [ProjectValidationIssue]
    @Binding var isValidating: Bool
    let store: CMSStore
    @State private var validationTask: Task<Void, Never>?
    private let validationClock = ContinuousClock()

    func body(content: Content) -> some View {
        content
            .onChange(of: liveMarkdownEnabled) { _, enabled in
                if !enabled {
                    editorMode = .edit
                } else if editorMode == .edit {
                    editorMode = .split
                }
            }
            .onChange(of: editorMode) { _, mode in
                store.recordUXEvent("editor.mode.switch", metadata: mode.rawValue)
            }
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
                restoreDisclosureStateIfNeeded()
                validationIssues = ProjectValidator.validate(document)
                isValidating = false
            }
            .onDisappear {
                validationTask?.cancel()
                validationTask = nil
                isValidating = false
            }
            .onChange(of: advancedExpanded) { _, value in
                store.recordExpandedDisclosure("project.advanced", isExpanded: value)
            }
            .onChange(of: videoMetaExpanded) { _, value in
                store.recordExpandedDisclosure("project.videoMeta", isExpanded: value)
            }
            .onChange(of: caseStudyExpanded) { _, value in
                store.recordExpandedDisclosure("project.caseStudy", isExpanded: value)
            }
            .onChange(of: heroExpanded) { _, value in
                store.recordExpandedDisclosure("project.hero", isExpanded: value)
            }
    }

    private func restoreDisclosureStateIfNeeded() {
        guard !didLoadDisclosureState else { return }
        didLoadDisclosureState = true
        advancedExpanded = store.expandedDisclosure("project.advanced", default: false)
        videoMetaExpanded = store.expandedDisclosure("project.videoMeta", default: false)
        caseStudyExpanded = store.expandedDisclosure("project.caseStudy", default: false)
        heroExpanded = store.expandedDisclosure("project.hero", default: false)
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

/// Renders markdown as the user types, with a small debounce so large
/// documents stay responsive while still feeling immediate.
private struct LiveMarkdownPreview: View {
    private static let perfLogger = Logger(subsystem: "com.subtext.app", category: "ux.preview")
    private let previewClock = ContinuousClock()

    let markdown: String
    let lineSpacing: CGFloat

    @State private var rendered = AttributedString("")
    @State private var renderError: String?
    @State private var renderTask: Task<Void, Never>?
    private let renderer = MarkdownPreviewRenderer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let renderError {
                    Label(renderError, systemImage: "exclamationmark.triangle.fill")
                        .font(SubtextUI.Typography.caption)
                        .foregroundStyle(Color.subtextWarning)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SubtextUI.Surface.warningBannerFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous))
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
            GlassSurface(prominence: .interactive, cornerRadius: SubtextUI.Radius.large) { Color.clear }
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
            let started = previewClock.now
            let output = await renderer.render(text: text)
            guard !Task.isCancelled else { return }
            rendered = output.rendered
            renderError = output.errorMessage
            logRenderLatency(
                started: started,
                textLength: text.count,
                didFallbackToPlainText: output.usedPlainTextFallback
            )
        }
    }

    private func logRenderLatency(
        started: ContinuousClock.Instant,
        textLength: Int,
        didFallbackToPlainText: Bool
    ) {
        let elapsed = previewClock.now - started
        let elapsedMs = elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000
        let fallback = didFallbackToPlainText ? "fallback" : "ok"
        Self.perfLogger.info("preview.render \(elapsedMs)ms chars=\(textLength) state=\(fallback)")
    }
}

private actor MarkdownPreviewRenderer {
    struct Output {
        var rendered: AttributedString
        var errorMessage: String?
        var usedPlainTextFallback: Bool
    }

    func render(text: String) -> Output {
        do {
            return Output(
                rendered: try AttributedString(
                    markdown: text,
                    options: .init(interpretedSyntax: .full)
                ),
                errorMessage: nil,
                usedPlainTextFallback: false
            )
        } catch {
            return Output(
                rendered: AttributedString(text),
                errorMessage: "Some markdown could not be parsed. Showing plain text until syntax is fixed.",
                usedPlainTextFallback: true
            )
        }
    }
}
