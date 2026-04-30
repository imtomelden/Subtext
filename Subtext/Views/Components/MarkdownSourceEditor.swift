import AppKit
import SwiftUI

/// `NSTextView`-backed editor with inline markdown syntax highlighting.
/// Uses `MarkdownTextStorage` to apply visual formatting (heading sizes,
/// bold, italic, dimmed markers) as the user types — Bear-style.
///
/// Preserves the original behaviours: snippet insertion at the caret,
/// no smart-quotes/dashes, transparent background, and undo support.
struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var font: NSFont
    var insets: CGSize = CGSize(width: 24, height: 20)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = MarkdownTextStorage(baseFont: font)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.textContainerInset = insets
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator

        // Populate initial content — set directly on storage to trigger highlighting.
        if !text.isEmpty {
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        }

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              let storage = textView.textStorage as? MarkdownTextStorage
        else { return }

        if storage.baseFont != font {
            storage.baseFont = font
        }

        if storage.string != text {
            let savedRange = textView.selectedRange()
            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            let len = storage.length
            let clampedLocation = min(savedRange.location, len)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
        }

        if textView.selectedRange() != selection {
            let len = storage.length
            let location = max(0, min(selection.location, len))
            let length = max(0, min(selection.length, len - location))
            textView.setSelectedRange(NSRange(location: location, length: length))
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownSourceEditor

        init(_ parent: MarkdownSourceEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            if parent.text != newText {
                parent.text = newText
            }
            let range = textView.selectedRange()
            if parent.selection != range {
                parent.selection = range
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            if parent.selection != range {
                parent.selection = range
            }
        }
    }
}
