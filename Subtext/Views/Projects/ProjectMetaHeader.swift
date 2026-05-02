import SwiftUI

/// Inline metadata header sitting above the body editor.
/// Shows the document title, a chip row with slug/ownership/date/tags,
/// and the description field. The ··· button opens the full inspector panel.
struct ProjectMetaHeader: View {
    @Binding var document: ProjectDocument
    var validationIssues: [ProjectValidationIssue]
    var isValidating: Bool
    @Binding var slugManuallyEdited: Bool
    var titleDerivedSlug: String
    var onSyncSlug: () -> Void
    var onShowInspector: () -> Void

    @State private var isEditingSlug = false
    @State private var isAddingTag = false
    @State private var tagInput = ""
    @State private var showDatePicker = false
    @FocusState private var slugFocused: Bool
    @FocusState private var tagFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleField
                .padding(.bottom, 10)

            chipRow
                .padding(.bottom, 16)

            Rectangle()
                .fill(Tokens.Border.subtle)
                .frame(height: 1)
                .padding(.bottom, 20)

            descriptionField
                .padding(.bottom, 28)
        }
    }

    // MARK: - Title

    private var titleField: some View {
        TextField("Untitled project", text: $document.frontmatter.title)
            .textFieldStyle(.plain)
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(Tokens.Text.primary)
            .tracking(-0.78)  // ≈ -0.03em at 26px
    }

    // MARK: - Chip Row

    private var chipRow: some View {
        HStack(spacing: 0) {
            // Wrapping chip flow
            HStack(spacing: 6) {
                slugChip
                vDivider
                ownershipChip
                dateChip
                vDivider
                tagsRow
            }

            Spacer(minLength: 12)

            // Validation status + overflow
            HStack(spacing: 6) {
                validationStatus
                moreButton
            }
        }
    }

    // MARK: - Slug chip

    private var slugChip: some View {
        Group {
            if isEditingSlug {
                TextField("slug", text: $document.frontmatter.slug)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .frame(minWidth: 80)
                    .focused($slugFocused)
                    .onAppear { slugFocused = true }
                    .onSubmit { commitSlug() }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Tokens.Fill.metaCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Tokens.Border.focus, lineWidth: 1)
                            )
                    )
            } else {
                Button { isEditingSlug = true } label: {
                    HStack(spacing: 5) {
                        Text("/" + document.frontmatter.slug)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Tokens.Text.tertiary)
                        if !slugManuallyEdited {
                            Text("AUTO")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(Color.subtextAccent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(Color.subtextAccent.opacity(0.10))
                                )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Tokens.Fill.metaCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Tokens.Border.metaCard, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Edit slug — currently \(slugManuallyEdited ? "manually set" : "auto-generated from title")")
            }
        }
        .onChange(of: slugFocused) { _, focused in
            if !focused { commitSlug() }
        }
        .onChange(of: document.frontmatter.slug) { _, _ in
            slugManuallyEdited = true
        }
    }

    private func commitSlug() {
        isEditingSlug = false
        if document.frontmatter.slug.isEmpty {
            document.frontmatter.slug = titleDerivedSlug
            slugManuallyEdited = false
        }
    }

    // MARK: - Ownership chip

    private var ownershipChip: some View {
        Button {
            let all = ProjectFrontmatter.Ownership.allCases
            let idx = all.firstIndex(of: document.frontmatter.ownership) ?? 0
            document.frontmatter.ownership = all[(idx + 1) % all.count]
        } label: {
            Text(document.frontmatter.ownership.displayName)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.subtextAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.subtextAccent.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.subtextAccent.opacity(0.20), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Tap to toggle ownership")
    }

    // MARK: - Date chip

    private var dateChip: some View {
        Button { showDatePicker.toggle() } label: {
            Text(formattedDate)
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.Text.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Tokens.Fill.metaCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Tokens.Border.metaCard, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
            datePickerPopover
        }
    }

    private var formattedDate: String {
        if let date = ISO8601Date.parse(document.frontmatter.date) {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: date)
        }
        return document.frontmatter.date
    }

    private var datePickerPopover: some View {
        VStack(spacing: 0) {
            if let date = ISO8601Date.parse(document.frontmatter.date) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date },
                        set: { document.frontmatter.date = ISO8601Date.format($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(12)
                .frame(width: 280)
            } else {
                SubtextTextField("YYYY-MM-DD", text: $document.frontmatter.date)
                    .padding(12)
                    .frame(width: 200)
            }
        }
    }

    // MARK: - Tags row

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(document.frontmatter.tags, id: \.self) { tag in
                    tagChip(tag)
                }

                if isAddingTag {
                    TextField("tag", text: $tagInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .frame(minWidth: 50)
                        .focused($tagFocused)
                        .onAppear { tagFocused = true }
                        .onSubmit { commitTag() }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Tokens.Fill.tag)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(Tokens.Border.focus, lineWidth: 1)
                                )
                        )
                        .onChange(of: tagFocused) { _, focused in
                            if !focused { commitTag() }
                        }
                } else {
                    addTagChip
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.Text.secondary)
                .lineLimit(1)
            Button {
                document.frontmatter.tags.removeAll { $0 == tag }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            .buttonStyle(.plain)
        }
        .fixedSize()
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Tokens.Fill.tag)
        )
    }

    private var addTagChip: some View {
        Button { isAddingTag = true } label: {
            Text("+ tag")
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.Text.tertiary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .foregroundStyle(Tokens.Border.subtle)
                )
        }
        .buttonStyle(.plain)
    }

    private func commitTag() {
        let cleaned = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleaned.isEmpty && !document.frontmatter.tags.contains(cleaned) {
            document.frontmatter.tags.append(cleaned)
        }
        tagInput = ""
        isAddingTag = false
    }

    // MARK: - Validation status

    private var validationStatus: some View {
        Group {
            if isValidating {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini).scaleEffect(0.7)
                    Text("Validating…")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
            } else if validationIssues.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                    Text("No issues")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Tokens.Text.tertiary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Tokens.State.warning)
                    Text("\(validationIssues.count) issue\(validationIssues.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Text.secondary)
                }
                .help(validationIssues.map { "• \($0.message)" }.joined(separator: "\n"))
            }
        }
    }

    // MARK: - More button

    private var moreButton: some View {
        Button { onShowInspector() } label: {
            Text("···")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.Text.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Tokens.Fill.metaCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Tokens.Border.metaCard, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Open advanced inspector")
    }

    // MARK: - Description

    private var descriptionField: some View {
        TextField("Add a short description…", text: $document.frontmatter.description, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13).italic())
            .foregroundStyle(Tokens.Text.tertiary)
            .lineLimit(2...4)
    }

    // MARK: - Helpers

    private var vDivider: some View {
        Rectangle()
            .fill(Tokens.Border.subtle)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 4)
    }
}
