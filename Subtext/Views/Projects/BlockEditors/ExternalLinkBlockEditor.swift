import SwiftUI

struct ExternalLinkBlockEditor: View {
    @Binding var block: ExternalLinkBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("URL") {
                TextField("https://…", text: $block.href)
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow("Button label") {
                TextField("View project →", text: Binding(
                    get: { block.label ?? "" },
                    set: { block.label = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
