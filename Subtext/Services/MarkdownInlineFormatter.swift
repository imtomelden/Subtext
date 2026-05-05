import Foundation

struct MarkdownInlineFormatter {
    enum Style {
        case bold
        case italic
        case link
        case infoChip
    }

    struct Result {
        let text: String
        let selection: NSRange
    }

    static func apply(style: Style, to text: String, selection: NSRange) -> Result {
        let nsText = text as NSString
        let clamped = clamp(selection, length: nsText.length)
        let token = token(for: style)

        if clamped.length > 0 {
            let selected = nsText.substring(with: clamped)
            let replacement = token.prefix + selected + token.suffix
            let updated = nsText.replacingCharacters(in: clamped, with: replacement)
            let resolvedSelection: NSRange
            if token.preferPlaceholderSelectionAfterWrap {
                resolvedSelection = NSRange(
                    location: clamped.location + token.placeholderSelection.location,
                    length: token.placeholderSelection.length
                )
            } else {
                let selectedStart = clamped.location + (token.prefix as NSString).length
                let selectedLength = (selected as NSString).length
                resolvedSelection = NSRange(location: selectedStart, length: selectedLength)
            }
            return Result(
                text: updated,
                selection: resolvedSelection
            )
        }

        let updated = nsText.replacingCharacters(in: clamped, with: token.placeholder)
        let placeholderStart = clamped.location + token.placeholderSelection.location
        return Result(
            text: updated,
            selection: NSRange(location: placeholderStart, length: token.placeholderSelection.length)
        )
    }

    private struct Token {
        let prefix: String
        let suffix: String
        let placeholder: String
        let placeholderSelection: NSRange
        let preferPlaceholderSelectionAfterWrap: Bool
    }

    private static func token(for style: Style) -> Token {
        switch style {
        case .bold:
            return Token(
                prefix: "**",
                suffix: "**",
                placeholder: "**bold**",
                placeholderSelection: NSRange(location: 2, length: 4),
                preferPlaceholderSelectionAfterWrap: false
            )
        case .italic:
            return Token(
                prefix: "*",
                suffix: "*",
                placeholder: "*italic*",
                placeholderSelection: NSRange(location: 1, length: 6),
                preferPlaceholderSelectionAfterWrap: false
            )
        case .link:
            return Token(
                prefix: "[",
                suffix: "](https://)",
                placeholder: "[link text](https://)",
                placeholderSelection: NSRange(location: 1, length: 9),
                preferPlaceholderSelectionAfterWrap: false
            )
        case .infoChip:
            return Token(
                prefix: "\\{\\{chip:Tooltip text|",
                suffix: "\\}\\}",
                placeholder: "\\{\\{chip:Tooltip text|chip label\\}\\}",
                placeholderSelection: NSRange(location: 10, length: 12),
                preferPlaceholderSelectionAfterWrap: true
            )
        }
    }

    private static func clamp(_ range: NSRange, length: Int) -> NSRange {
        let location = max(0, min(range.location, length))
        let span = max(0, min(range.length, length - location))
        return NSRange(location: location, length: span)
    }
}
