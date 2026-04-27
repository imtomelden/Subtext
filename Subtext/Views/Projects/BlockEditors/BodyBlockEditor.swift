import SwiftUI

struct BodyBlockEditor: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The project’s main MDX content is inserted at the position of this block.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
