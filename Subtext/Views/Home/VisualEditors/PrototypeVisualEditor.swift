import SwiftUI

struct PrototypeVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        if case .prototype(let model) = visual {
            VStack(alignment: .leading, spacing: 12) {
                FieldRow("Section") {
                    Picker("", selection: bindingSection(model: model)) {
                        ForEach(PrototypeVisual.Section.allCases) { section in
                            Text(section.displayName).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                FieldRow("Idea") {
                    Picker("", selection: bindingIdea(model: model)) {
                        Text("Idea 1").tag(1)
                        Text("Idea 2").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        } else {
            EmptyView()
        }
    }

    private func bindingSection(model: PrototypeVisual) -> Binding<PrototypeVisual.Section> {
        Binding(
            get: { model.section },
            set: { next in
                visual = .prototype(PrototypeVisual(section: next, idea: model.idea))
            }
        )
    }

    private func bindingIdea(model: PrototypeVisual) -> Binding<Int> {
        Binding(
            get: { model.idea },
            set: { next in
                visual = .prototype(PrototypeVisual(section: model.section, idea: next))
            }
        )
    }
}
