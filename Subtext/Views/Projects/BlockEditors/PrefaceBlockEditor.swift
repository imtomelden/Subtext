import SwiftUI

struct PrefaceBlockEditor: View {
    @Binding var block: PrefaceBlock
    @State private var showPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Shown before the MDX body. Supports markdown: **bold**, *italic*, [links](url).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(showPreview ? "Edit" : "Preview") {
                    showPreview.toggle()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if showPreview {
                markdownPreview
            } else {
                FieldRow("Text") {
                    VStack(alignment: .trailing, spacing: 4) {
                        TextField("e.g. I wrote this piece in 2023.", text: $block.text, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...8)
                        let words = block.text
                            .components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }
                            .count
                        if words > 0 {
                            Text("\(words) words")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var markdownPreview: some View {
        let rendered: Text = {
            if let attrStr = try? AttributedString(
                markdown: block.text.isEmpty ? "*Nothing to preview yet.*" : block.text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                return Text(attrStr)
            }
            return Text(block.text)
        }()
        return rendered
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(SubtextUI.Surface.subtleFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small))
    }
}
