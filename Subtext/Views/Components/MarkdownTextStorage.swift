import AppKit

/// Custom `NSTextStorage` that applies inline markdown syntax highlighting
/// as the user types. Markdown markers (`#`, `**`, `_`, `` ` ``) are
/// rendered in a dimmed tertiary colour so they visually recede, while the
/// text they annotate is rendered with the appropriate font weight, size, or
/// style — giving a Bear-like WYSIWYG feel without hiding the raw source.
final class MarkdownTextStorage: NSTextStorage {

    // MARK: - Configuration

    /// Body prose font. Heading sizes are derived from this base.
    var baseFont: NSFont {
        didSet {
            guard oldValue != baseFont else { return }
            reHighlightAll()
        }
    }

    // MARK: - Private

    private let backing = NSMutableAttributedString()
    private var isApplyingAttributes = false

    // Pre-compiled regex patterns (static so they are only compiled once).
    private static let headingPattern = try! NSRegularExpression(
        pattern: #"^(#{1,6})([ \t]*)(.*)$"#,
        options: .anchorsMatchLines
    )
    private static let boldPattern = try! NSRegularExpression(
        pattern: #"\*\*(.+?)\*\*"#
    )
    private static let italicAsteriskPattern = try! NSRegularExpression(
        // Single asterisk italic — avoids matching inside **bold**.
        pattern: #"(?<!\*)\*(?!\*)([^\n]+?)(?<!\*)\*(?!\*)"#
    )
    private static let italicUnderscorePattern = try! NSRegularExpression(
        pattern: #"(?<![_\w])_([^\n_]+?)_(?![_\w])"#
    )
    private static let codeSpanPattern = try! NSRegularExpression(
        pattern: #"`([^`\n]+)`"#
    )
    private static let blockquotePattern = try! NSRegularExpression(
        pattern: #"^(>[ \t]?)(.*)$"#,
        options: .anchorsMatchLines
    )
    private static let linkPattern = try! NSRegularExpression(
        pattern: #"(\[)([^\]]+)(\]\()([^)]+)(\))"#
    )
    private static let hrPattern = try! NSRegularExpression(
        pattern: #"^[ \t]*([-*_][ \t]*){3,}$"#,
        options: .anchorsMatchLines
    )

    // MARK: - Init

    init(baseFont: NSFont) {
        self.baseFont = baseFont
        super.init()
    }

    required init?(coder: NSCoder) {
        self.baseFont = .systemFont(ofSize: NSFont.systemFontSize)
        super.init(coder: coder)
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        return nil
    }

    // MARK: - NSTextStorage primitives

    override var string: String {
        backing.string
    }

    override func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        guard !isApplyingAttributes else { return }
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Highlighting

    override func processEditing() {
        // Extend to full paragraph boundaries so multi-character markdown
        // patterns that span the edited range are fully re-evaluated.
        let paragraphRange = (backing.string as NSString).paragraphRange(for: editedRange)
        applyHighlighting(in: paragraphRange)
        super.processEditing()
    }

    private func reHighlightAll() {
        let fullRange = NSRange(location: 0, length: backing.length)
        guard fullRange.length > 0 else { return }
        beginEditing()
        applyHighlighting(in: fullRange)
        endEditing()
    }

    private func applyHighlighting(in range: NSRange) {
        let text = backing.string as NSString
        let len = backing.length
        guard len > 0 else { return }
        let safeRange = NSRange(
            location: range.location,
            length: min(range.length, len - range.location)
        )
        guard safeRange.length > 0 else { return }

        isApplyingAttributes = true
        defer { isApplyingAttributes = false }

        // 1. Reset to base prose style.
        backing.setAttributes(proseAttributes, range: safeRange)

        // 2. Apply markdown patterns. Order matters: headings before italic so
        //    a heading `## *foo*` doesn't double-apply.
        applyHeadings(to: safeRange, text: text)
        applyBlockquotes(to: safeRange, text: text)
        applyCodeSpans(to: safeRange, text: text)
        applyBold(to: safeRange, text: text)
        applyItalicAsterisk(to: safeRange, text: text)
        applyItalicUnderscore(to: safeRange, text: text)
        applyLinks(to: safeRange, text: text)
        applyHR(to: safeRange, text: text)
    }

    // MARK: - Pattern appliers

    private func applyHeadings(to range: NSRange, text: NSString) {
        Self.headingPattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            let hashRange = match.range(at: 1)
            let spaceRange = match.range(at: 2)
            let contentRange = match.range(at: 3)
            let hashCount = hashRange.length

            let markerRange = NSUnionRange(hashRange, spaceRange)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markerRange)

            if contentRange.length > 0 {
                backing.addAttributes([
                    .font: headingFont(level: hashCount),
                    .foregroundColor: NSColor.labelColor
                ], range: contentRange)
            }
        }
    }

    private func applyBlockquotes(to range: NSRange, text: NSString) {
        Self.blockquotePattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            let markerRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markerRange)
            if contentRange.length > 0 {
                backing.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: contentRange)
            }
        }
    }

    private func applyCodeSpans(to range: NSRange, text: NSString) {
        Self.codeSpanPattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            let fullRange = match.range
            backing.addAttributes([
                .font: monoFont,
                .foregroundColor: NSColor.secondaryLabelColor,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.08)
            ], range: fullRange)
        }
    }

    private func applyBold(to range: NSRange, text: NSString) {
        Self.boldPattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            let fullRange = match.range
            let contentRange = match.range(at: 1)

            // Dim the ** markers by applying tertiary colour to the 2-char
            // marker at each end, derived from the full match range.
            let openRange = NSRange(location: fullRange.location, length: 2)
            let closeRange = NSRange(location: NSMaxRange(fullRange) - 2, length: 2)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
            if contentRange.length > 0 {
                backing.addAttribute(.font, value: boldFont, range: contentRange)
            }
        }
    }

    private func applyItalicAsterisk(to range: NSRange, text: NSString) {
        Self.italicAsteriskPattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            let fullRange = match.range
            let contentRange = match.range(at: 1)

            let openRange = NSRange(location: fullRange.location, length: 1)
            let closeRange = NSRange(location: NSMaxRange(fullRange) - 1, length: 1)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
            if contentRange.length > 0 {
                backing.addAttribute(.font, value: italicFont, range: contentRange)
            }
        }
    }

    private func applyItalicUnderscore(to range: NSRange, text: NSString) {
        Self.italicUnderscorePattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            let fullRange = match.range
            let contentRange = match.range(at: 1)

            let openRange = NSRange(location: fullRange.location, length: 1)
            let closeRange = NSRange(location: NSMaxRange(fullRange) - 1, length: 1)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
            if contentRange.length > 0 {
                backing.addAttribute(.font, value: italicFont, range: contentRange)
            }
        }
    }

    private func applyLinks(to range: NSRange, text: NSString) {
        Self.linkPattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            // Groups: [1](2)(3)(4)(5)
            // [       =  1
            // text    =  2
            // ](      =  3
            // url     =  4
            // )       =  5
            let bracketOpen = match.range(at: 1)
            let linkText = match.range(at: 2)
            let bracketClose = match.range(at: 3)
            let url = match.range(at: 4)
            let parenClose = match.range(at: 5)

            for markerRange in [bracketOpen, bracketClose, url, parenClose] {
                if markerRange.location != NSNotFound {
                    backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markerRange)
                }
            }
            if linkText.location != NSNotFound && linkText.length > 0 {
                backing.addAttribute(.foregroundColor, value: NSColor.linkColor, range: linkText)
            }
        }
    }

    private func applyHR(to range: NSRange, text: NSString) {
        Self.hrPattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let match else { return }
            backing.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: match.range)
        }
    }

    // MARK: - Font helpers

    private var proseAttributes: [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4.0
        return [.font: baseFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: para]
    }

    private func headingFont(level: Int) -> NSFont {
        let sizes: [CGFloat] = [26, 22, 18, 16, 14, 13]
        let size = sizes[min(level - 1, sizes.count - 1)]
        return NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    private var boldFont: NSFont {
        NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
    }

    private var italicFont: NSFont {
        NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
    }

    private var monoFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: max(baseFont.pointSize - 1, 11), weight: .regular)
    }
}
