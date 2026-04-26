import AppKit
import SwiftUI

/// `NSTextView`-backed source editor used by the MDX project body. Exists so
/// the markdown toolbar can splice snippets in at the caret instead of always
/// appending — which `SwiftUI.TextEditor` does not expose. Also keeps the
/// monospaced/body font toggle, transparent background, and disabled "smart"
/// behaviours (auto-quotes, dashes, link detection) that are hostile to
/// markdown source.
struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var font: NSFont
    var insets: CGSize = CGSize(width: 12, height: 12)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.delegate = context.coordinator
        textView.isRichText = false
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
        textView.font = font
        textView.textColor = NSColor.labelColor
        textView.string = text
        textView.setSelectedRange(selection)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.font != font {
            textView.font = font
            if let storage = textView.textStorage {
                storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))
            }
        }

        if textView.string != text {
            let previous = textView.selectedRange()
            textView.string = text
            let clamped = NSRange(
                location: min(previous.location, (text as NSString).length),
                length: 0
            )
            textView.setSelectedRange(clamped)
        }

        if textView.selectedRange() != selection {
            let length = (textView.string as NSString).length
            let location = max(0, min(selection.location, length))
            let span = max(0, min(selection.length, length - location))
            textView.setSelectedRange(NSRange(location: location, length: span))
        }
    }

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
