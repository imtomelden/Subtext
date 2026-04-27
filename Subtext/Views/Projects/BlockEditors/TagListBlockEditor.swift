import SwiftUI

struct TagListBlockEditor: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Renders the project’s tags from frontmatter in page order. Edit tags in the project sidebar.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
