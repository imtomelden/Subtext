import SwiftUI

/// Right-side inspector panel containing all project frontmatter fields.
struct ProjectInspectorPanel: View {
    @Binding var document: ProjectDocument
    var validationIssues: [ProjectValidationIssue]
    var isValidating: Bool
    var slugManuallyEdited: Bool

    @Environment(CMSStore.self) private var store
    @State private var advancedExpanded = false
    @State private var caseStudyExpanded = false
    @State private var heroExpanded = false
    @State private var videoMetaExpanded = false
    @State private var didRestoreDisclosureState = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                panelHeader
                Divider()
                validationRow
                fieldsBody
            }
        }
        .onAppear {
            guard !didRestoreDisclosureState else { return }
            didRestoreDisclosureState = true
            advancedExpanded = store.expandedDisclosure("project.advanced", default: false)
            caseStudyExpanded = store.expandedDisclosure("project.caseStudy", default: false)
            heroExpanded = store.expandedDisclosure("project.hero", default: false)
            videoMetaExpanded = store.expandedDisclosure("project.videoMeta", default: false)
        }
        .onChange(of: advancedExpanded)    { _, v in store.recordExpandedDisclosure("project.advanced", isExpanded: v) }
        .onChange(of: caseStudyExpanded)   { _, v in store.recordExpandedDisclosure("project.caseStudy", isExpanded: v) }
        .onChange(of: heroExpanded)        { _, v in store.recordExpandedDisclosure("project.hero", isExpanded: v) }
        .onChange(of: videoMetaExpanded)   { _, v in store.recordExpandedDisclosure("project.videoMeta", isExpanded: v) }
    }

    // MARK: - Header

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(document.frontmatter.title.isEmpty ? "Untitled project" : document.frontmatter.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)
                .lineLimit(2)
            Text(document.fileName)
                .font(.caption.monospaced())
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Validation

    private var validationRow: some View {
        return ZStack(alignment: .leading) {
            validationIdleState.opacity(!isValidating && validationIssues.isEmpty ? 1 : 0)
            validationValidatingState.opacity(isValidating ? 1 : 0)
            validationIssuesState.opacity(!isValidating && !validationIssues.isEmpty ? 1 : 0)
        }
        .frame(height: 18, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .help(validationIssues.map { "• \($0.message)" }.joined(separator: "\n"))
        .animation(nil, value: isValidating)
        .animation(nil, value: validationIssues.count)
    }

    private var validationIdleState: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Tokens.Text.tertiary)
            Text("No issues")
                .font(.caption2)
                .foregroundStyle(Tokens.Text.tertiary)
            Spacer()
        }
    }

    private var validationValidatingState: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.mini)
            Text("Validating…")
                .font(.caption2)
                .foregroundStyle(Tokens.Text.tertiary)
            Spacer()
        }
    }

    private var validationIssuesState: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.subtextWarning)
            Text("\(validationIssues.count) issue\(validationIssues.count == 1 ? "" : "s")")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.subtextWarning)
                .monospacedDigit()
            Spacer()
        }
    }

    // MARK: - Fields

    private var fieldsBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            essentialsSection
            InspectorSection(title: "Advanced", isExpanded: $advancedExpanded) {
                advancedFields
            }
            InspectorSection(title: "Case study", isExpanded: $caseStudyExpanded) {
                caseStudyFields
            }
            InspectorSection(title: "Hero override", isExpanded: $heroExpanded) {
                heroFields
            }
            if document.frontmatter.tags.contains(where: { $0.caseInsensitiveCompare("video") == .orderedSame }) {
                InspectorSection(title: "Video metadata", isExpanded: $videoMetaExpanded) {
                    videoFields
                }
            }
        }
        .padding(16)
    }

    // MARK: - Always-visible Essentials

    @ViewBuilder
    private var essentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            FieldRow("Description") {
                TextField("Short description", text: $document.frontmatter.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            FieldRow("Date") {
                DateField(value: $document.frontmatter.date)
            }

            FieldRow("Tags") {
                TagEditor(tags: $document.frontmatter.tags)
            }
        }
    }

    // MARK: - Collapsible Sections

    @ViewBuilder
    private var advancedFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldRow("Slug") {
                TextField("kebab-case-slug", text: $document.frontmatter.slug)
                    .textFieldStyle(.roundedBorder)
            }
            if !slugManuallyEdited {
                Text("Auto-generated from title")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
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

            HStack(spacing: 16) {
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
    }

    @ViewBuilder
    private var caseStudyFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldRow("Role")     { TextField("e.g. Lead designer", text: optionalBinding(\.role)).textFieldStyle(.roundedBorder) }
            FieldRow("Duration") { TextField("e.g. 3 months", text: optionalBinding(\.duration)).textFieldStyle(.roundedBorder) }
            FieldRow("Impact")   { TextField("Headline outcome", text: optionalBinding(\.impact), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...3) }
            FieldRow("Challenge"){ TextField("What problem this addressed", text: optionalBinding(\.challenge), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...3) }
            FieldRow("Approach") { TextField("How you tackled it", text: optionalBinding(\.approach), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...3) }
            FieldRow("Outcome")  { TextField("What shipped", text: optionalBinding(\.outcome), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...3) }
        }
    }

    @ViewBuilder
    private var heroFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overrides the hero block. Leave empty to use title and description.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.tertiary)
            FieldRow("Eyebrow")  { TextField("Small label above title", text: heroBinding(\.eyebrow)).textFieldStyle(.roundedBorder) }
            FieldRow("Title")    { TextField("Hero title", text: heroBinding(\.title)).textFieldStyle(.roundedBorder) }
            FieldRow("Subtitle") { TextField("Hero subtitle", text: heroBinding(\.subtitle), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...3) }
        }
    }

    @ViewBuilder
    private var videoFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldRow("Runtime")      { TextField("e.g. 3m 45s", text: optionalVideoMetaBinding(\.runtime)).textFieldStyle(.roundedBorder) }
            FieldRow("Platform")     { TextField("YouTube, Vimeo…", text: optionalVideoMetaBinding(\.platform)).textFieldStyle(.roundedBorder) }
            FieldRow("Transcript")   { TextField("https://…", text: optionalVideoMetaBinding(\.transcriptUrl)).textFieldStyle(.roundedBorder) }
            FieldRow("Credits") {
                StringListEditor(
                    items: videoMetaCreditsBinding,
                    placeholder: "Credit entry",
                    addLabel: "Add credit",
                    showReorderControls: true
                )
            }
        }
    }

    // MARK: - Bindings

    private func optionalBinding(_ keyPath: WritableKeyPath<ProjectFrontmatter, String?>) -> Binding<String> {
        Binding(
            get: { document.frontmatter[keyPath: keyPath] ?? "" },
            set: { document.frontmatter[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

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
                var meta = document.frontmatter.videoMeta ?? .init(runtime: nil, platform: nil, transcriptUrl: nil, credits: [])
                meta.credits = newValue
                document.frontmatter.videoMeta = meta.isEmpty ? nil : meta
            }
        )
    }

    private func optionalVideoMetaBinding(_ keyPath: WritableKeyPath<ProjectFrontmatter.VideoMeta, String?>) -> Binding<String> {
        Binding(
            get: { document.frontmatter.videoMeta?[keyPath: keyPath] ?? "" },
            set: { newValue in
                var meta = document.frontmatter.videoMeta ?? .init(runtime: nil, platform: nil, transcriptUrl: nil, credits: [])
                meta[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                document.frontmatter.videoMeta = meta.isEmpty ? nil : meta
            }
        )
    }
}

// MARK: - Inspector Section

/// Custom collapsible section with an animated rotating chevron — replaces `DisclosureGroup`.
private struct InspectorSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(UXMotion.spring) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Text.secondary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
