import SwiftUI

struct DividerBlockEditor: View {
    var body: some View {
        Label("Renders as a visual section divider on the website.", systemImage: "minus")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
