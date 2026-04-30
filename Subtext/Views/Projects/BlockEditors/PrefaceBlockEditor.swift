import SwiftUI

struct PrefaceBlockEditor: View {
    @Binding var block: PrefaceBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shown before the MDX body. Markdown is supported (e.g. **bold**, [links](https://example.com), short lists).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            FieldRow("Text") {
                TextField("e.g. I wrote this piece in 2023.", text: $block.text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
            }
        }
    }
}
