import SwiftUI

struct ProjectsListView: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.contentDensity) private var density
    @State private var showNewProjectSheet = false
    @State private var deleteTarget: ProjectDocument?
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Sticky header — stays fixed while list scrolls
            listHeader
            Divider()

            // Search field
            searchField
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider()

            // Scrollable project list
            ScrollView {
                if filteredProjects.isEmpty {
                    emptyState
                        .padding(.horizontal, 10)
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: density.listRowSpacing) {
                        let seoIssuesByFileName = seoIssuesLookup(for: filteredProjects)
                        ForEach(filteredProjects) { project in
                            ProjectListCard(
                                document: project,
                                seoIssues: seoIssuesByFileName[project.fileName] ?? [],
                                isSelected: store.selectedProjectFileName == project.fileName
                            ) {
                                store.selectedProjectFileName = project.fileName
                            } onDelete: {
                                deleteTarget = project
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .padding(.bottom, 60)
                }
            }
        }
        .sheet(isPresented: $showNewProjectSheet) {
            NewProjectSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextNewItem)) { _ in
            showNewProjectSheet = true
        }
        .alert(item: $deleteTarget) { target in
            Alert(
                title: Text("Delete \u{201C}\(target.frontmatter.title)\u{201D}?"),
                message: Text("A backup is saved first. The file will be removed from /src/content/projects."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await store.deleteProject(target.fileName) }
                },
                secondaryButton: .cancel()
            )
        }
        // ⌘F focuses the search field
        .onKeyPress(.init("f"), phases: .down) { event in
            guard event.modifiers.contains(.command) else { return .ignored }
            searchFocused = true
            return .handled
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Projects")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Tokens.Text.primary)
                Text("\(store.projects.count) projects")
                    .font(.caption2)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            Spacer()

            Button {
                showNewProjectSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .subtextButton(.icon)
            .help("New project (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.Text.tertiary)

            TextField("Search projects", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($searchFocused)

            if !searchText.isEmpty {
                Button {
                    withAnimation(UXMotion.micro) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                .fill(Tokens.Background.sunken)
        )
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: SubtextUI.Radius.medium, style: .continuous)
                    .fill(Tokens.Accent.subtleFill)
                Image(systemName: searchText.isEmpty ? "doc.badge.plus" : "magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.subtextAccent)
            }
            .frame(width: 52, height: 52)

            Text(searchText.isEmpty ? "No projects yet" : "No results")
                .font(.callout.weight(.medium))
                .foregroundStyle(Tokens.Text.primary)

            if searchText.isEmpty {
                Text("Press ⌘N to create your first case study.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Try a different title, slug, or tag.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Helpers

    private var filteredProjects: [ProjectDocument] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.projects }
        return store.projects.filter { doc in
            doc.frontmatter.title.lowercased().contains(q)
                || doc.frontmatter.slug.lowercased().contains(q)
                || doc.frontmatter.tags.contains { $0.lowercased().contains(q) }
        }
    }

    private func seoIssuesLookup(for projects: [ProjectDocument]) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: projects.map { ($0.fileName, SEOPreview.issues(for: $0)) })
    }
}

// MARK: - Project List Card

private struct ProjectListCard: View {
    let document: ProjectDocument
    let seoIssues: [String]
    var isSelected: Bool = false
    var onOpen: () -> Void
    var onDelete: () -> Void
    @Environment(CMSStore.self) private var store
    @State private var isHovered = false

    var body: some View {
        let isDirty = store.isProjectDirty(document.fileName)

        HStack(alignment: .center, spacing: 10) {
            // Ownership dot
            Circle()
                .fill(document.frontmatter.ownership.tint)
                .frame(width: 8, height: 8)
                .accessibilityLabel("\(document.frontmatter.ownership.displayName) project")

            // Main content — two lines
            VStack(alignment: .leading, spacing: 3) {
                // Line 1: title + badges
                HStack(spacing: 5) {
                    Text(document.frontmatter.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Tokens.Text.primary)
                        .lineLimit(1)

                    if document.frontmatter.featured {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }

                    if document.frontmatter.draft {
                        Text("Draft")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.subtextWarning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.subtextWarning.opacity(0.15)))
                    }

                    if isDirty {
                        Circle()
                            .fill(Color.subtextAccent)
                            .frame(width: 6, height: 6)
                    }

                    if !seoIssues.isEmpty {
                        Text("SEO \(seoIssues.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.subtextWarning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.subtextWarning.opacity(0.15)))
                            .help(seoIssues.joined(separator: "\n"))
                    }
                }

                // Line 2: description
                if !document.frontmatter.description.isEmpty {
                    Text(document.frontmatter.description)
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing: date + delete
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Tokens.Text.tertiary)

                if isHovered {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tokens.Text.tertiary)
                    .help("Delete project")
                    .accessibilityLabel("Delete \(document.frontmatter.title)")
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                .fill(isSelected ? Tokens.Accent.subtleFill : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.subtextAccent.opacity(0.25) : Color.clear,
                    lineWidth: 0.5
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous))
        .onTapGesture(perform: onOpen)
        .onHover { isHovered = $0 }
        .animation(UXMotion.micro, value: isHovered)
        .animation(UXMotion.micro, value: isSelected)
    }

    private var formattedDate: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: document.frontmatter.date) else {
            return document.frontmatter.date
        }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}

// MARK: - New Project Sheet

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
                .subtextButton(.primary)
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
