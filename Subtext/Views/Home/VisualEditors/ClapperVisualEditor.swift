import SwiftUI

struct ClapperVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                FieldRow("Scene") {
                    TextField("e.g. 1", text: bind(\.scene))
                        .textFieldStyle(.roundedBorder)
                }
                FieldRow("Take") {
                    TextField("e.g. 1", text: bind(\.take))
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack(spacing: 12) {
                FieldRow("Roll") {
                    TextField("e.g. A", text: bind(\.roll))
                        .textFieldStyle(.roundedBorder)
                }
                FieldRow("Loc") {
                    TextField("e.g. Manchester", text: bind(\.loc))
                        .textFieldStyle(.roundedBorder)
                }
            }
            Text("The site shows today’s date (UK) next to location automatically; only Loc is stored here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func bind(_ keyPath: WritableKeyPath<ClapperVisual, String>) -> Binding<String> {
        Binding(
            get: {
                if case .clapper(let c) = visual { return c[keyPath: keyPath] }
                return ""
            },
            set: { newValue in
                guard case .clapper(var c) = visual else { return }
                c[keyPath: keyPath] = newValue
                visual = .clapper(c)
            }
        )
    }
}
