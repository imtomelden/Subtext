import SwiftUI

struct HeaderImageBlockEditor: View {
    @Binding var block: HeaderImageBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Image path") {
                TextField("/images/…", text: $block.src)
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow("Alt text") {
                TextField("Optional", text: Binding(
                    get: { block.alt ?? "" },
                    set: { block.alt = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
