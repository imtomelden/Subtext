import SwiftUI

struct HeaderImageBlockEditor: View {
    @Binding var block: HeaderImageBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Image") {
                AssetPathField(path: $block.src, placeholder: "/images/…")
            }
            FieldRow("Alt text") {
                TextField("Optional description for screen readers", text: Binding(
                    get: { block.alt ?? "" },
                    set: { block.alt = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
