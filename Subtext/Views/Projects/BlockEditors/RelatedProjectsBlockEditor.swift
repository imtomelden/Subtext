import SwiftUI

struct RelatedProjectsBlockEditor: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Renders a short list of related projects (same site section / shared tags), computed at build time.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
