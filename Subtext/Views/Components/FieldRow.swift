import SwiftUI

/// Labelled text field row used throughout editors. Consistent label width
/// keeps editors visually aligned.
struct FieldRow<Field: View>: View {
    let label: String
    @ViewBuilder let field: () -> Field

    init(_ label: String, @ViewBuilder field: @escaping () -> Field) {
        self.label = label
        self.field = field
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            field()
        }
    }
}

/// Multi-row string list editor. Used for body paragraphs, scramble words,
/// terminal lines, and block highlights.
struct StringListEditor: View {
    @Binding var items: [String]
    var placeholder: String = "Enter text"
    var addLabel: String = "Add"
    var multiline: Bool = false
    var showReorderControls: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, _ in
                HStack(alignment: .top, spacing: 8) {
                    if multiline {
                        TextEditor(text: binding(for: idx))
                            .font(.body)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        TextField(placeholder, text: binding(for: idx))
                            .textFieldStyle(.roundedBorder)
                    }

                    if showReorderControls {
                        VStack(spacing: 4) {
                            Button {
                                moveItem(at: idx, by: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .disabled(idx == 0)

                            Button {
                                moveItem(at: idx, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .disabled(idx >= items.count - 1)
                        }
                    }

                    Button(role: .destructive) {
                        items.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            Button {
                items.append("")
            } label: {
                Label(addLabel, systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.subtextAccent)
        }
    }

    private func binding(for idx: Int) -> Binding<String> {
        Binding(
            get: { idx < items.count ? items[idx] : "" },
            set: { value in
                guard idx < items.count else { return }
                items[idx] = value
            }
        )
    }

    private func moveItem(at index: Int, by delta: Int) {
        let destination = index + delta
        guard index >= 0, index < items.count else { return }
        guard destination >= 0, destination < items.count else { return }
        let item = items.remove(at: index)
        items.insert(item, at: destination)
    }
}
