import SwiftUI

struct ProjectsListView: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density
    @State private var showNewProjectSheet = false
    @State private var deleteTarget: ProjectDocument?
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: density.sectionOuterSpacing) {
                header

                searchField
                    .padding(.horizontal, density.sectionOuterSpacing)

                if filteredProjects.isEmpty {
                    emptyState
                        .padding(.horizontal, density.sectionOuterSpacing)
                } else {
                    LazyVStack(spacing: density.listRowSpacing) {
                        ForEach(filteredProjects) { project in
                            ProjectListCard(document: project) {
                                store.selectedProjectFileName = project.fileName
                            } onDelete: {
                                deleteTarget = project
                            }
                        }
                    }
                    .padding(.horizontal, density.sectionOuterSpacing)
                    .padding(.bottom, 80)
                }
            }
            .padding(.top, density.canvasTopPadding)
        }
        .sheet(isPresented: $showNewProjectSheet) {
            NewProjectSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextNewItem)) { _ in
            showNewProjectSheet = true
        }
        .alert(item: $deleteTarget) { target in
            Alert(
                title: Text("Delete “\(target.frontmatter.title)”?"),
                message: Text("A backup is saved first. The file will be removed from /src/content/projects."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await store.deleteProject(target.fileName) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var filteredProjects: [ProjectDocument] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.projects }
        return store.projects.filter { doc in
            doc.frontmatter.title.lowercased().contains(q)
                || doc.frontmatter.slug.lowercased().contains(q)
                || doc.frontmatter.tags.contains { $0.lowercased().contains(q) }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Projects")
                    .font(.largeTitle.weight(.semibold))
                Text("\(store.projects.count) case studies in /src/content/projects")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 10) {
                RevealInFinderButton(
                    url: RepoConstants.projectsDirectory,
                    helpText: "Reveal projects folder in Finder"
                )

                Button {
                    showNewProjectSheet = true
                } label: {
                    Label("New project", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.subtextAccent)
            }
        }
        .padding(.horizontal, density.sectionOuterSpacing)
    }

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search projects", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No projects yet" : "No projects match “\(searchText)”")
                .font(.callout.weight(.medium))
            if searchText.isEmpty {
                Text("Create your first case study with the “New project” button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct ProjectListCard: View {
    let document: ProjectDocument
    var onOpen: () -> Void
    var onDelete: () -> Void
    @Environment(CMSStore.self) private var store

    var body: some View {
        let isDirty = store.isProjectDirty(document.fileName)

        DraggableCard {
            categoryPill
        } content: {
            HStack(alignment: .top, spacing: 10) {
                if let thumbnail = document.frontmatter.thumbnail, !thumbnail.isEmpty {
                    AssetMediaThumbnail(src: thumbnail, size: 44, cornerRadius: 7)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(document.frontmatter.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        if document.frontmatter.featured {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                        if document.frontmatter.draft {
                            Text("DRAFT")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.orange.opacity(0.18)))
                        }
                        if isDirty {
                            Circle()
                                .fill(Color.subtextAccent)
                                .frame(width: 6, height: 6)
                        }
                        seoBadge
                    }
                    Text(document.frontmatter.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !document.frontmatter.tags.isEmpty {
                        Text(document.frontmatter.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        } trailing: {
            HStack(spacing: 6) {
                Text(document.frontmatter.date)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)

                Button {
                    onOpen()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Open project")
                .accessibilityLabel("Open \(document.frontmatter.title)")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Delete project")
                .accessibilityLabel("Delete \(document.frontmatter.title)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    /// Cheap inline SEO lint — title length, description presence, thumbnail,
    /// date validity, slug/file match. Shown as an amber pill linking to the
    /// site audit sheet for details.
    @ViewBuilder
    private var seoBadge: some View {
        let issues = SEOPreview.issues(for: document)
        if !issues.isEmpty {
            Text("SEO \(issues.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.subtextWarning)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.subtextWarning.opacity(0.18)))
                .help(issues.joined(separator: "\n"))
        } else {
            EmptyView()
        }
    }

    private var categoryPill: some View {
        let tint = document.frontmatter.ownership.tint
        return Text(document.frontmatter.ownership.displayName.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.18)))
            .accessibilityLabel("\(document.frontmatter.ownership.displayName) ownership")
    }
}

private struct NewProjectSheet: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var slug: String = ""
    @State private var ownership: ProjectFrontmatter.Ownership = .work

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New project")
                .font(.title2.weight(.semibold))

            FieldRow("Title") {
                TextField("Project title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: title) { _, newValue in
                        if slug.isEmpty {
                            slug = Self.slugify(newValue)
                        }
                    }
            }

            FieldRow("Slug") {
                TextField("a-kebab-case-slug", text: $slug)
                    .textFieldStyle(.roundedBorder)
            }

            FieldRow("Ownership") {
                Picker("Ownership", selection: $ownership) {
                    ForEach(ProjectFrontmatter.Ownership.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Create") {
                    Task {
                        await store.createProject(slug: slug, title: title, ownership: ownership)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.subtextAccent)
                .keyboardShortcut(.defaultAction)
                .disabled(slug.isEmpty || title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
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
