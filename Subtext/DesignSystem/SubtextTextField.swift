import SwiftUI

/// Design-system text input — replaces `.textFieldStyle(.roundedBorder)` with
/// semantic token colours, an accent focus ring, and a `Motion.snappy` animation.
///
/// **Usage** (drop-in for `TextField + .textFieldStyle(.roundedBorder)`):
///
///     SubtextTextField("Placeholder", text: $text)
///     SubtextTextField("Placeholder", text: $text, axis: .vertical, lineLimit: 2...4)
///
/// Leave Settings on stock `Form` / `TextField` — those benefit from the
/// system groupedForm treatment and are styled by macOS, not us.
struct SubtextTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis
    var lineLimit: ClosedRange<Int>?

    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.axis = axis
        self.lineLimit = lineLimit
    }

    var body: some View {
        Group {
            if let range = lineLimit {
                field.lineLimit(range.lowerBound...range.upperBound)
            } else {
                field
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(inputBackground)
        .animation(Motion.snappy, value: isFocused)
    }

    // MARK: - Private

    private var field: some View {
        TextField(placeholder, text: $text, axis: axis)
            .textFieldStyle(.plain)
            .focused($isFocused)
    }

    private var inputBackground: some View {
        let shape = RoundedRectangle(cornerRadius: SubtextUI.Radius.tiny, style: .continuous)
        return shape
            .fill(Tokens.Background.sunken)
            .overlay(
                shape.strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.55) : Tokens.Border.default,
                    lineWidth: isFocused ? 1.5 : 1
                )
            )
    }
}
