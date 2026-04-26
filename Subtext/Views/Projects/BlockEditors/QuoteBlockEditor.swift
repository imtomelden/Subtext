import SwiftUI

struct QuoteBlockEditor: View {
    @Binding var block: QuoteBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Quote") {
                TextField("The quote", text: $block.quote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
            }
            FieldRow("Attribution name") {
                TextField("Optional attribution", text: Binding(
                    get: { block.attributionName ?? "" },
                    set: { block.attributionName = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Role/context") {
                TextField("Role or organisation context", text: Binding(
                    get: { block.attributionRoleContext ?? "" },
                    set: { block.attributionRoleContext = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Theme tag") {
                TextField("impact, delivery, confidence…", text: Binding(
                    get: { block.theme ?? "" },
                    set: { block.theme = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
