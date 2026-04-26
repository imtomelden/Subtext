import SwiftUI

/// Labelled date control that binds to the `YYYY-MM-DD` string format used
/// in frontmatter. If the string isn't parseable (empty, manual value, or a
/// format we don't support), falls back to a plain text field so nothing is
/// ever lost.
struct DateField: View {
    @Binding var value: String

    var body: some View {
        if let date = ISO8601Date.parse(value) {
            HStack(spacing: 8) {
                DatePicker(
                    "",
                    selection: dateBinding(fallback: date),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.field)

                Text(value)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 8) {
                TextField("YYYY-MM-DD", text: $value)
                    .textFieldStyle(.roundedBorder)

                Button {
                    value = ISO8601Date.today()
                } label: {
                    Image(systemName: "calendar")
                }
                .buttonStyle(.bordered)
                .help("Use today's date")
            }
        }
    }

    private func dateBinding(fallback: Date) -> Binding<Date> {
        Binding(
            get: { ISO8601Date.parse(value) ?? fallback },
            set: { value = ISO8601Date.format($0) }
        )
    }
}
