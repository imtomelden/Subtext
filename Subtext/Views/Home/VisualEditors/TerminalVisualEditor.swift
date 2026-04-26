import SwiftUI

struct TerminalVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Window title") {
                TextField("e.g. tinkerer.js", text: titleBinding)
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow("Lines") {
                StringListEditor(
                    items: linesBinding,
                    placeholder: "Line text",
                    addLabel: "Add line"
                )
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: {
                if case .terminal(let t) = visual { return t.title }
                return ""
            },
            set: { newValue in
                guard case .terminal(var t) = visual else { return }
                t.title = newValue
                visual = .terminal(t)
            }
        )
    }

    private var linesBinding: Binding<[String]> {
        Binding(
            get: {
                if case .terminal(let t) = visual { return t.lines }
                return []
            },
            set: { newValue in
                guard case .terminal(var t) = visual else { return }
                t.lines = newValue
                visual = .terminal(t)
            }
        )
    }
}
