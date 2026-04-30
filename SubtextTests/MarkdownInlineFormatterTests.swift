import XCTest
@testable import Subtext

final class MarkdownInlineFormatterTests: XCTestCase {
    func testItalicWrapsSelectedText() {
        let result = MarkdownInlineFormatter.apply(
            style: .italic,
            to: "hello world",
            selection: NSRange(location: 6, length: 5)
        )

        XCTAssertEqual(result.text, "hello *world*")
        XCTAssertEqual(result.selection, NSRange(location: 7, length: 5))
    }

    func testBoldWrapsSelectedText() {
        let result = MarkdownInlineFormatter.apply(
            style: .bold,
            to: "hello world",
            selection: NSRange(location: 6, length: 5)
        )

        XCTAssertEqual(result.text, "hello **world**")
        XCTAssertEqual(result.selection, NSRange(location: 8, length: 5))
    }

    func testCollapsedItalicInsertsTemplateAndSelectsPlaceholder() {
        let result = MarkdownInlineFormatter.apply(
            style: .italic,
            to: "hello ",
            selection: NSRange(location: 6, length: 0)
        )

        XCTAssertEqual(result.text, "hello *italic*")
        XCTAssertEqual(result.selection, NSRange(location: 7, length: 6))
    }

    func testSelectionRangeClampsNearTextBoundary() {
        let result = MarkdownInlineFormatter.apply(
            style: .italic,
            to: "hello",
            selection: NSRange(location: 3, length: 10)
        )

        XCTAssertEqual(result.text, "hel*lo*")
        XCTAssertEqual(result.selection, NSRange(location: 4, length: 2))
    }

    func testCollapsedInfoChipInsertsTemplateAndSelectsTooltip() {
        let result = MarkdownInlineFormatter.apply(
            style: .infoChip,
            to: "hello ",
            selection: NSRange(location: 6, length: 0)
        )

        XCTAssertEqual(result.text, "hello \\{\\{chip:Tooltip text|chip label\\}\\}")
        XCTAssertEqual(result.selection, NSRange(location: 16, length: 12))
    }

    func testInfoChipWrapsSelectedTextAsLabel() {
        let result = MarkdownInlineFormatter.apply(
            style: .infoChip,
            to: "hello world",
            selection: NSRange(location: 6, length: 5)
        )

        XCTAssertEqual(result.text, "hello \\{\\{chip:Tooltip text|world\\}\\}")
        XCTAssertEqual(result.selection, NSRange(location: 16, length: 12))
    }

    func testInfoChipSelectionRangeClampsNearTextBoundary() {
        let result = MarkdownInlineFormatter.apply(
            style: .infoChip,
            to: "hello",
            selection: NSRange(location: 3, length: 10)
        )

        XCTAssertEqual(result.text, "hel\\{\\{chip:Tooltip text|lo\\}\\}")
        XCTAssertEqual(result.selection, NSRange(location: 13, length: 12))
    }
}
