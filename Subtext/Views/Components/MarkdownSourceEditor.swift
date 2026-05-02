import AppKit
import SwiftUI

/// `NSTextView`-backed editor with inline markdown syntax highlighting.
/// Uses `MarkdownTextStorage` to apply visual formatting (heading sizes,
/// bold, italic, dimmed markers) as the user types — Bear-style.
///
/// Preserves the original behaviours: snippet insertion at the caret,
/// no smart-quotes/dashes, transparent background, and undo support.
///
/// **Typewriter mode** — when `typewriterHeight` is set, the editor renders
/// at that fixed height and scrolls internally so the insertion point stays
/// at ~40% from the top of the visible area. The parent no longer needs to
/// supply `contentHeight`; pass `nil` for that binding in typewriter mode.
struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var font: NSFont
    var insets: CGSize = CGSize(width: 24, height: 20)
    /// Receives the editor's natural content height so the host can size the
    /// view correctly and let a parent SwiftUI ScrollView handle all scrolling.
    /// Pass `nil` when using `typewriterHeight`.
    var contentHeight: Binding<CGFloat>? = nil
    /// When set, the editor switches to typewriter mode: it renders at this
    /// fixed height and scrolls internally to keep the caret at ~40% from top.
    var typewriterHeight: CGFloat? = nil
    /// Called when the user types `/` at the start of a line.
    /// The host view can use this to present a block-insertion overlay.
    var onSlashAtLineStart: (() -> Void)?

    var isTypewriterMode: Bool { typewriterHeight != nil }

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
        textView.usesFindBar = true
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
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = false

        context.coordinator.attachTextFinder(scrollView: scrollView, textView: textView)

        return scrollView
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.tearDownTextFinder()
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

        if let h = typewriterHeight {
            // In typewriter mode the SwiftUI frame is fixed; ensure the text
            // view fills at least that height so short documents still scroll.
            if textView.frame.height < h {
                textView.frame.size.height = h
            }
            context.coordinator.scrollForTypewriter(textView, visibleHeight: h)
        } else if contentHeight != nil {
            DispatchQueue.main.async {
                context.coordinator.updateContentHeight(for: textView)
            }
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownSourceEditor
        private var textFinder: NSTextFinder?
        private var finderObservers: [NSObjectProtocol] = []

        init(_ parent: MarkdownSourceEditor) {
            self.parent = parent
        }

        func attachTextFinder(scrollView: NSScrollView, textView: NSTextView) {
            textFinder?.client = nil
            textFinder = nil
            finderObservers.forEach { NotificationCenter.default.removeObserver($0) }
            finderObservers.removeAll()

            let finder = NSTextFinder()
            finder.findBarContainer = scrollView
            // `NSTextFinder.client` is typed as `NSTextFinderClient` which Swift 6 does not surface on `NSTextView`.
            finder.setValue(textView, forKey: "client")
            textFinder = finder

            let replaceNote = NotificationCenter.default.addObserver(
                forName: .subtextMarkdownShowReplace,
                object: nil,
                queue: .main
            ) { [weak self, weak textView] _ in
                Task { [weak self, weak textView] in
                    await MainActor.run { [weak self, weak textView] in
                        guard let self, let textView, let finder = self.textFinder else { return }
                        textView.window?.makeFirstResponder(textView)
                        finder.performAction(.showReplaceInterface)
                    }
                }
            }
            finderObservers.append(replaceNote)
        }

        func tearDownTextFinder() {
            finderObservers.forEach { NotificationCenter.default.removeObserver($0) }
            finderObservers.removeAll()
            textFinder?.setValue(nil, forKey: "client")
            textFinder = nil
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            if replacementString == "/", let callback = parent.onSlashAtLineStart {
                let nsString = textView.string as NSString
                let lineRange = nsString.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
                if affectedCharRange.location == lineRange.location {
                    callback()
                }
            }
            return true
        }

        func updateContentHeight(for textView: NSTextView) {
            guard let binding = parent.contentHeight,
                  let lm = textView.layoutManager,
                  let tc = textView.textContainer else { return }
            lm.ensureLayout(for: tc)
            let used = lm.usedRect(for: tc)
            let h = ceil(used.height + textView.textContainerInset.height * 2)
            let newHeight = max(260, h)
            if abs(binding.wrappedValue - newHeight) > 0.5 {
                binding.wrappedValue = newHeight
            }
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
            if let h = parent.typewriterHeight {
                scrollForTypewriter(textView, visibleHeight: h)
            } else {
                updateContentHeight(for: textView)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            if parent.selection != range {
                parent.selection = range
            }
            if let h = parent.typewriterHeight {
                scrollForTypewriter(textView, visibleHeight: h)
            }
        }

        // MARK: - Typewriter scroll

        /// Scrolls the clip view so the insertion point sits at ~40% from
        /// the top of the visible area, giving the writer more context below.
        func scrollForTypewriter(_ textView: NSTextView, visibleHeight: CGFloat) {
            guard let lm = textView.layoutManager,
                  let tc = textView.textContainer,
                  let scrollView = textView.enclosingScrollView
            else { return }

            lm.ensureLayout(for: tc)

            let caretLoc = max(0, min(textView.selectedRange().location,
                                      (textView.string as NSString).length))
            let glyphIdx = lm.isValidGlyphIndex(caretLoc)
                ? caretLoc
                : lm.numberOfGlyphs > 0 ? lm.numberOfGlyphs - 1 : 0
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            let caretY = lineRect.midY + textView.textContainerInset.height

            // Target: caret at 40% from visible top.
            let targetOriginY = caretY - visibleHeight * 0.40
            let contentH = textView.frame.height
            let maxOriginY = max(0, contentH - visibleHeight)
            let clampedY = max(0, min(targetOriginY, maxOriginY))

            let currentY = scrollView.contentView.bounds.origin.y
            guard abs(currentY - clampedY) > 1 else { return }

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: clampedY))
            }
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

// MARK: - NSLayoutManager helper

private extension NSLayoutManager {
    func isValidGlyphIndex(_ idx: Int) -> Bool {
        idx >= 0 && idx < numberOfGlyphs
    }
}

