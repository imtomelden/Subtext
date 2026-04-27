import SwiftUI

struct PageHeroBlockEditor: View {
    @Binding var block: PageHeroBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Eyebrow") {
                TextField("Optional", text: Binding(
                    get: { block.eyebrow ?? "" },
                    set: { block.eyebrow = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Title") {
                TextField("Optional", text: Binding(
                    get: { block.title ?? "" },
                    set: { block.title = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            FieldRow("Subtitle") {
                TextField("Optional", text: Binding(
                    get: { block.subtitle ?? "" },
                    set: { block.subtitle = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
        }
    }
}
