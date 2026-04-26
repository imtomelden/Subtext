import SwiftUI

struct NarrativeBlockEditor: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Narrative block")
                .font(.body.weight(.medium))

            Text("A narrative block renders the markdown body of the project inline at this position. Edit the body in the main editor below the blocks list.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color.subtextAccent)
                Text("No per-block configuration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 9))
        }
    }
}
