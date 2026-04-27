import SwiftUI

struct CaseStudyBlockEditor: View {
    @Binding var block: CaseStudyBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Role") {
                TextField("Optional", text: Binding(
                    get: { block.role ?? "" },
                    set: { block.role = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Timeline") {
                TextField("Optional", text: Binding(
                    get: { block.duration ?? "" },
                    set: { block.duration = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Challenge") {
                TextField("Optional", text: Binding(
                    get: { block.challenge ?? "" },
                    set: { block.challenge = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
            }
            FieldRow("Approach") {
                TextField("Optional", text: Binding(
                    get: { block.approach ?? "" },
                    set: { block.approach = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
            }
            FieldRow("Outcome") {
                TextField("Optional", text: Binding(
                    get: { block.outcome ?? "" },
                    set: { block.outcome = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
            }
        }
    }
}
