import SwiftUI

struct TicketVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Passenger") {
                TextField("Name", text: bind(\.passenger))
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow("Route") {
                TextField("e.g. Any permitted", text: bind(\.route))
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 12) {
                FieldRow("From") {
                    TextField("Origin", text: bind(\.from))
                        .textFieldStyle(.roundedBorder)
                }
                FieldRow("To") {
                    TextField("Destination", text: bind(\.to))
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack(spacing: 12) {
                FieldRow("From code") {
                    TextField("e.g. SNL", text: codeBind(\.fromCode))
                        .textFieldStyle(.roundedBorder)
                }
                FieldRow("To code") {
                    TextField("e.g. MAN", text: codeBind(\.toCode))
                        .textFieldStyle(.roundedBorder)
                }
            }
            FieldRow("Date") {
                TextField("e.g. Sep 2010", text: bind(\.date))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func bind(_ keyPath: WritableKeyPath<TicketVisual, String>) -> Binding<String> {
        Binding(
            get: {
                if case .ticket(let t) = visual { return t[keyPath: keyPath] }
                return ""
            },
            set: { newValue in
                guard case .ticket(var t) = visual else { return }
                t[keyPath: keyPath] = newValue
                visual = .ticket(t)
            }
        )
    }

    private func codeBind(_ keyPath: WritableKeyPath<TicketVisual, String>) -> Binding<String> {
        Binding(
            get: {
                if case .ticket(let t) = visual { return t[keyPath: keyPath] }
                return ""
            },
            set: { newValue in
                guard case .ticket(var t) = visual else { return }
                let normalized = String(
                    newValue
                        .uppercased()
                        .filter { $0.isLetter }
                        .prefix(3)
                )
                t[keyPath: keyPath] = normalized
                visual = .ticket(t)
            }
        )
    }
}
