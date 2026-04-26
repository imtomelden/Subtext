import AppKit
import SwiftUI

/// Compact strip of markdown insert helpers for the project body editor.
///
/// When `selection` is bound to a live `NSTextView` (via `MarkdownSourceEditor`)
/// snippets are spliced in at the caret. If no selection is provided the toolbar
/// degrades to its previous append-only behaviour so callers without an
/// `NSTextView` bridge still work.
struct MarkdownInsertToolbar: View {
    @Binding var text: String
    var selection: Binding<NSRange>? = nil

    @State private var showImagePathPickerError = false
    @State private var imagePickerErrorMessage = ""

    var body: some View {
        HStack(spacing: 6) {
            headingMenu
            insertButton(
                system: "bold",
                help: insertHelp("bold text"),
                snippet: "**bold**",
                placeholder: NSRange(location: 2, length: 4)
            )
            insertButton(
                system: "italic",
                help: insertHelp("italic text"),
                snippet: "*italic*",
                placeholder: NSRange(location: 1, length: 6)
            )
            insertButton(
                system: "list.bullet",
                help: insertHelp("bullet list"),
                snippet: "\n- Item\n- Item\n- Item\n"
            )
            insertButton(
                system: "list.number",
                help: insertHelp("numbered list"),
                snippet: "\n1. First\n2. Second\n3. Third\n"
            )
            insertButton(
                system: "link",
                help: insertHelp("link"),
                snippet: "[link text](https://)",
                placeholder: NSRange(location: 1, length: 9)
            )
            Button(action: insertImageFromLibrary) {
                Image(systemName: "photo")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Insert image from /public")
            insertButton(
                system: "quote.opening",
                help: insertHelp("blockquote"),
                snippet: "\n> Quote\n"
            )
            insertButton(
                system: "chevron.left.forwardslash.chevron.right",
                help: insertHelp("code block"),
                snippet: "\n```\ncode\n```\n"
            )
            insertButton(
                system: "list.bullet.rectangle",
                help: insertHelp("task list"),
                snippet: "\n- [ ] Task one\n- [ ] Task two\n"
            )
            insertButton(
                system: "rectangle.split.3x1",
                help: insertHelp("table"),
                snippet: "\n| Column | Column |\n| --- | --- |\n| Value | Value |\n"
            )
            insertButton(
                system: "minus",
                help: insertHelp("divider"),
                snippet: "\n---\n"
            )
        }
        .controlSize(.small)
        .alert("File not inside /public", isPresented: $showImagePathPickerError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imagePickerErrorMessage)
        }
    }

    /// Opens a `/public`-rooted file panel and inserts a markdown image
    /// reference using the resolved relative path. Uses the file's stem as
    /// fallback alt text so the inserted snippet is at least navigable.
    private func insertImageFromLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = RepoConstants.publicDirectory
        panel.prompt = "Insert"
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let chosen = panel.url else { return }

        let publicPath = RepoConstants.publicDirectory.path(percentEncoded: false)
        let chosenPath = chosen.path(percentEncoded: false)
        guard chosenPath.hasPrefix(publicPath) else {
            imagePickerErrorMessage = "Pick a file from /public so it resolves on the site.\n\n\(chosenPath)"
            showImagePathPickerError = true
            return
        }
        let relative = String(chosenPath.dropFirst(publicPath.count))
        let webPath = relative.hasPrefix("/") ? relative : "/" + relative
        let alt = chosen.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        insert(snippet: "![\(alt)](\(webPath))", placeholder: NSRange(location: 2, length: alt.count))
    }

    private var headingMenu: some View {
        Menu {
            Button("Heading 1") { insert(snippet: "# Heading", placeholder: NSRange(location: 2, length: 7)) }
            Button("Heading 2") { insert(snippet: "## Heading", placeholder: NSRange(location: 3, length: 7)) }
            Button("Heading 3") { insert(snippet: "### Heading", placeholder: NSRange(location: 4, length: 7)) }
        } label: {
            Image(systemName: "textformat.size")
        }
        .menuStyle(.borderlessButton)
        .help(insertHelp("heading"))
    }

    @ViewBuilder
    private func insertButton(
        system: String,
        help: String,
        snippet: String,
        placeholder: NSRange? = nil
    ) -> some View {
        Button {
            insert(snippet: snippet, placeholder: placeholder)
        } label: {
            Image(systemName: system)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help)
    }

    /// Splices `snippet` into `text` at the caret (when `selection` is bound),
    /// adding minimal padding so block-level snippets sit on their own line.
    /// `placeholder` selects a range *inside* the inserted snippet so the user
    /// lands ready to type the meaningful part (e.g. the link URL).
    private func insert(snippet: String, placeholder: NSRange? = nil) {
        guard let selection = selection else {
            appendSnippet(snippet)
            return
        }

        let nsText = text as NSString
        let range = clampRange(selection.wrappedValue, length: nsText.length)
        let needsLeadingNewline = needsLeadingNewline(at: range.location, in: nsText, snippet: snippet)
        let needsTrailingNewline = needsTrailingNewline(at: range.location + range.length, in: nsText, snippet: snippet)
        let prefix = needsLeadingNewline ? "\n" : ""
        let suffix = needsTrailingNewline ? "\n" : ""
        let composed = prefix + snippet + suffix

        let updated = nsText.replacingCharacters(in: range, with: composed) as String
        text = updated

        if let placeholder, range.location + prefix.count + placeholder.location <= updated.utf16.count {
            let newLocation = range.location + prefix.count + placeholder.location
            selection.wrappedValue = NSRange(location: newLocation, length: placeholder.length)
        } else {
            let caret = range.location + (composed as NSString).length
            selection.wrappedValue = NSRange(location: caret, length: 0)
        }
    }

    /// Block-level snippets (lists, tables, etc.) want a blank line above them
    /// when inserted mid-paragraph. Inline snippets (bold, italic, link) don't.
    private func needsLeadingNewline(at location: Int, in text: NSString, snippet: String) -> Bool {
        guard snippet.first == "\n" else { return false }
        if location == 0 { return false }
        let prevChar = text.substring(with: NSRange(location: location - 1, length: 1))
        return prevChar != "\n"
    }

    private func needsTrailingNewline(at location: Int, in text: NSString, snippet: String) -> Bool {
        guard snippet.last == "\n" else { return false }
        if location >= text.length { return false }
        let nextChar = text.substring(with: NSRange(location: location, length: 1))
        return nextChar != "\n"
    }

    private func clampRange(_ range: NSRange, length: Int) -> NSRange {
        let location = max(0, min(range.location, length))
        let span = max(0, min(range.length, length - location))
        return NSRange(location: location, length: span)
    }

    private func appendSnippet(_ snippet: String) {
        var prefix = ""
        if !text.isEmpty && !text.hasSuffix("\n") { prefix = "\n\n" }
        else if text.hasSuffix("\n") && !text.hasSuffix("\n\n") { prefix = "\n" }
        text += prefix + snippet
        if !snippet.hasSuffix("\n") { text += "\n" }
    }

    private func insertHelp(_ description: String) -> String {
        selection == nil ? "Append \(description)" : "Insert \(description)"
    }
}
