import SwiftUI

/// Compact strip of markdown insert helpers for the project body editor.
/// Keeps insertion append-only to avoid unstable selection management through
/// SwiftUI's TextEditor bridge while still covering common authoring actions.
struct MarkdownInsertToolbar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            headingMenu
            insertButton(
                system: "bold",
                help: "Append bold text",
                snippet: "\n\n**bold**\n"
            )
            insertButton(
                system: "italic",
                help: "Append italic text",
                snippet: "\n\n*italic*\n"
            )
            insertButton(
                system: "list.bullet",
                help: "Append bullet list",
                snippet: "\n\n- Item\n- Item\n- Item\n"
            )
            insertButton(
                system: "list.number",
                help: "Append numbered list",
                snippet: "\n\n1. First\n2. Second\n3. Third\n"
            )
            insertButton(
                system: "link",
                help: "Append link",
                snippet: "\n\n[link text](https://)\n"
            )
            insertButton(
                system: "photo",
                help: "Append image",
                snippet: "\n\n![alt text](/images/)\n"
            )
            insertButton(
                system: "quote.opening",
                help: "Append blockquote",
                snippet: "\n\n> Quote\n"
            )
            insertButton(
                system: "chevron.left.forwardslash.chevron.right",
                help: "Append code block",
                snippet: "\n\n```\ncode\n```\n"
            )
            insertButton(
                system: "list.bullet.rectangle",
                help: "Append task list",
                snippet: "\n\n- [ ] Task one\n- [ ] Task two\n"
            )
            insertButton(
                system: "rectangle.split.3x1",
                help: "Append table",
                snippet: "\n\n| Column | Column |\n| --- | --- |\n| Value | Value |\n"
            )
            insertButton(
                system: "minus",
                help: "Append divider",
                snippet: "\n\n---\n"
            )
        }
        .controlSize(.small)
    }

    private var headingMenu: some View {
        Menu {
            Button("Heading 1") { appendSnippet("\n\n# Heading\n") }
            Button("Heading 2") { appendSnippet("\n\n## Heading\n") }
            Button("Heading 3") { appendSnippet("\n\n### Heading\n") }
        } label: {
            Image(systemName: "textformat.size")
        }
        .menuStyle(.borderlessButton)
        .help("Append heading")
    }

    @ViewBuilder
    private func insertButton(system: String, help: String, snippet: String) -> some View {
        Button {
            appendSnippet(snippet)
        } label: {
            Image(systemName: system)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private func appendSnippet(_ snippet: String) {
        if !text.hasSuffix("\n") && !text.isEmpty {
            text += "\n"
        }
        text += snippet
    }
}
