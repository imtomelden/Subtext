import SwiftUI

struct ScrambleVisualEditor: View {
    @Binding var visual: VisualContent

    var body: some View {
        StringListEditor(
            items: wordsBinding,
            placeholder: "Word",
            addLabel: "Add word"
        )
    }

    private var wordsBinding: Binding<[String]> {
        Binding(
            get: {
                if case .scramble(let s) = visual { return s.words }
                return []
            },
            set: { visual = .scramble(ScrambleVisual(words: $0)) }
        )
    }
}
