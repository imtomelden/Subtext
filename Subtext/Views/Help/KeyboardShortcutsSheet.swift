import SwiftUI

/// In-app mirror of the command surface in `SubtextApp` / `ContentView`.
struct KeyboardShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(String, String)] = [
        ("Save", "⌘S"),
        ("Discard changes", "⇧⌘Z"),
        ("New item", "⌘N"),
        ("Bold in project body", "⌘B"),
        ("Italic in project body", "⌘I"),
        ("Heading in project body", "⌥⌘1"),
        ("Link in project body", "⌥⌘K"),
        ("Cycle project editor mode", "⌥⌘\\"),
        ("Go to…", "⌘K"),
        ("Find in content…", "⌘F"),
        ("Move selection up", "⌃⌥↑"),
        ("Move selection down", "⌃⌥↓"),
        ("Show live preview", "⌥⌘P"),
        ("Toggle focus mode", "⌃⌘F"),
        ("Commit & push…", "⇧⌘K"),
        ("Refresh git status", "⇧⌘R"),
        ("Retry (when load failed)", "⌘R"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard shortcuts")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.0)
                                .font(.body)
                            Spacer()
                            Text(row.1)
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 420, height: 420)
    }
}
