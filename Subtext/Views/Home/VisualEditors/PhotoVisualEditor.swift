import SwiftUI

struct PhotoVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Image path") {
                AssetPathField(path: bind(\.src), placeholder: "/images/... (homepage photo)")
            }
            FieldRow("Alt text") {
                TextField("Accessibility description", text: bind(\.alt))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func bind(_ keyPath: WritableKeyPath<PhotoVisual, String>) -> Binding<String> {
        Binding(
            get: {
                if case .photo(let p) = visual { return p[keyPath: keyPath] }
                return ""
            },
            set: { newValue in
                guard case .photo(var p) = visual else { return }
                p[keyPath: keyPath] = newValue
                visual = .photo(p)
            }
        )
    }
}
