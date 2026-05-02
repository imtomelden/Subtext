import SwiftUI

/// Manages presentation state for the slash-command block-insertion overlay.
///
/// Owned by `HomeEditorView`; activated when the user:
/// - Presses `/` with canvas focus.
/// - Clicks "Add section" (replaces the old `BlockPicker` sheet).
/// - Triggers `⌘N` (via `.subtextNewItem` notification).
///
/// Conforms to `Identifiable` so it can be used as the `item` parameter
/// for `.subtextModal(item:…)`.
@Observable
final class SlashCommandController: Identifiable {
    let id: String = "slashCommand"

    var isPresented: Bool = false
    var query: String = ""

    func activate() {
        query = ""
        isPresented = true
    }

    func dismiss() {
        isPresented = false
        query = ""
    }
}

// MARK: - Menu view

/// Slash-command overlay for inserting home page sections.
///
/// Mirrors `CommandPalette` layout: a `/`-prefixed search field, a `Divider`,
/// and a scrollable list of section type options. Uses `.command` modal style
/// so the host only provides the backdrop — the surface comes from
/// `GlassSurface` here.
struct SlashCommandMenu: View {
    @Binding var query: String
    var onSelect: (SplashSection.AddSectionOption) -> Void

    @Environment(\.dismissModal) private var dismiss
    @FocusState private var fieldFocused: Bool
    @State private var selectionIndex: Int = 0

    private var filteredOptions: [SplashSection.AddSectionOption] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return SplashSection.addSectionOptions }
        return SplashSection.addSectionOptions.filter {
            $0.displayName.lowercased().contains(q)
        }
    }

    var body: some View {
        GlassSurface(prominence: .thick, cornerRadius: SubtextUI.Glass.shellCornerRadius) {
            VStack(spacing: 0) {
                searchField
                    .padding(14)
                Divider()
                resultsList
            }
        }
        .frame(width: 480, height: 300)
        .onAppear {
            fieldFocused = true
            selectionIndex = 0
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    // MARK: - Search field

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 10) {
            Text("/")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.subtextAccent)
            TextField("Insert section…", text: $query)
                .font(.title3)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onSubmit { commitSelection() }
                .onKeyPress(.downArrow) { move(by: 1); return .handled }
                .onKeyPress(.upArrow) { move(by: -1); return .handled }
                .onChange(of: query) { _, _ in selectionIndex = 0 }
        }
    }

    // MARK: - Results list

    @ViewBuilder
    private var resultsList: some View {
        let options = filteredOptions
        if options.isEmpty {
            Text("No match for \"\(query)\"")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { idx, option in
                        SlashOptionRow(option: option, isSelected: idx == selectionIndex)
                            .onTapGesture { commit(option) }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - Helpers

    private func move(by delta: Int) {
        let count = filteredOptions.count
        guard count > 0 else { return }
        selectionIndex = (selectionIndex + delta + count) % count
    }

    private func commitSelection() {
        let options = filteredOptions
        guard selectionIndex < options.count else { return }
        commit(options[selectionIndex])
    }

    private func commit(_ option: SplashSection.AddSectionOption) {
        onSelect(option)
        dismiss()
    }
}

// MARK: - Row

private struct SlashOptionRow: View {
    let option: SplashSection.AddSectionOption
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: option.systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.subtextAccent)
                .frame(width: 28)
            Text(option.displayName)
                .font(.callout.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.subtextAccent.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
