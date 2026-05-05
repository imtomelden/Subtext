import SwiftUI

struct VideoDetailsBlockEditor: View {
    @Binding var block: VideoDetailsBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Runtime") {
                TextField("Optional", text: Binding(
                    get: { block.runtime ?? "" },
                    set: { block.runtime = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Platform") {
                TextField("Optional", text: Binding(
                    get: { block.platform ?? "" },
                    set: { block.platform = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Transcript URL") {
                TextField("https://…", text: Binding(
                    get: { block.transcriptUrl ?? "" },
                    set: { block.transcriptUrl = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Credits") {
                StringListEditor(
                    items: $block.credits,
                    placeholder: "Name / role",
                    addLabel: "Add credit",
                    showReorderControls: true
                )
            }
        }
    }
}
