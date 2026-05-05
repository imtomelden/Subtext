import SwiftUI

/// Sheet for renaming and merging tags across all projects.
/// Accessible from the Projects list header.
struct TagManagerSheet: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tagItems: [TagItem] = []
    @State private var editingTag: String?
    @State private var renameInput: String = ""
    @State private var mergeTarget: String?
    @State private var showMergePopover = false
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if tagItems.isEmpty {
                emptyState
            } else {
                tagList
            }
            Divider()
            footer
        }
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { rebuildTagItems() }
        .onChange(of: store.projects) { _, _ in rebuildTagItems() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Manage Tags")
                    .font(.title3.weight(.semibold))
                Text("\(tagItems.count) unique tag\(tagItems.count == 1 ? "" : "s") across \(store.projects.count) projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - List

    private var tagList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(tagItems) { item in
                    tagRow(item)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func tagRow(_ item: TagItem) -> some View {
        HStack(spacing: 12) {
            // Tag pill
            Text(item.tag)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.Text.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Tokens.Fill.tag))

            // Usage count
            Text("\(item.count) project\(item.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(Tokens.Text.tertiary)
                .monospacedDigit()

            Spacer()

            if editingTag == item.tag {
                // Inline rename field
                HStack(spacing: 6) {
                    TextField("New name", text: $renameInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .focused($renameFocused)
                        .onSubmit { commitRename(from: item.tag) }

                    Button("Rename") { commitRename(from: item.tag) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(Color.subtextAccent)
                        .disabled(renameInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Cancel") {
                        editingTag = nil
                        renameInput = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Button("Rename") {
                        editingTag = item.tag
                        renameInput = item.tag
                        renameFocused = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Menu("Merge into…") {
                        let others = tagItems.filter { $0.tag != item.tag }
                        if others.isEmpty {
                            Text("No other tags").foregroundStyle(.secondary)
                        } else {
                            ForEach(others) { other in
                                Button("\(other.tag) (\(other.count))") {
                                    mergeTag(item.tag, into: other.tag)
                                }
                            }
                        }
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                .fill(editingTag == item.tag ? Tokens.Accent.subtleFill : Color.clear)
        )
        .animation(UXMotion.micro, value: editingTag)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tag")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No tags yet")
                .font(.callout.weight(.medium))
            Text("Add tags to your projects from the editor.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func commitRename(from oldTag: String) {
        let newTag = renameInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !newTag.isEmpty, newTag != oldTag else {
            editingTag = nil
            renameInput = ""
            return
        }
        applyTagRename(from: oldTag, to: newTag)
        editingTag = nil
        renameInput = ""
    }

    private func mergeTag(_ source: String, into target: String) {
        applyTagRename(from: source, to: target)
    }

    private func applyTagRename(from oldTag: String, to newTag: String) {
        @Bindable var store = store
        for idx in store.projects.indices {
            guard store.projects[idx].frontmatter.tags.contains(oldTag) else { continue }
            store.projects[idx].frontmatter.tags = store.projects[idx].frontmatter.tags
                .map { $0 == oldTag ? newTag : $0 }
                .reduce(into: [String]()) { acc, tag in
                    if !acc.contains(tag) { acc.append(tag) }
                }
        }
        rebuildTagItems()
    }

    private func rebuildTagItems() {
        var counts: [String: Int] = [:]
        for project in store.projects {
            for tag in project.frontmatter.tags {
                counts[tag, default: 0] += 1
            }
        }
        tagItems = counts
            .map { TagItem(tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count || ($0.count == $1.count && $0.tag < $1.tag) }
    }
}

// MARK: - Supporting types

private struct TagItem: Identifiable, Equatable {
    let tag: String
    let count: Int
    var id: String { tag }
}
