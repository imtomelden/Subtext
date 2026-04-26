import SwiftUI

/// Pill-style tag input. Press Return to add, click a pill to remove.
struct TagEditor: View {
    @Binding var tags: [String]
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(Array(tags.enumerated()), id: \.offset) { idx, tag in
                    TagPill(text: tag) {
                        tags.remove(at: idx)
                    }
                }
            }

            TextField("Add tag…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTag)
        }
    }

    private func addTag() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            draft = ""
            return
        }
        tags.append(trimmed)
        draft = ""
    }
}

private struct TagPill: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.subtextAccent.opacity(0.20))
        )
        .overlay(Capsule().stroke(Color.subtextAccent.opacity(0.35), lineWidth: 0.5))
        .contentShape(Capsule())
        .onTapGesture(perform: onRemove)
    }
}

/// Basic flow layout for tag pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > width {
                totalHeight += currentRowHeight + spacing
                maxWidth = max(maxWidth, currentRowWidth)
                currentRowWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        totalHeight += currentRowHeight
        maxWidth = max(maxWidth, currentRowWidth)
        return CGSize(width: maxWidth.isFinite ? maxWidth : 0, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
