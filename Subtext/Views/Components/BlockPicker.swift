import SwiftUI

/// Modal picker that lets the user choose a new block or visual type.
struct BlockPicker<Kind: Hashable & Identifiable>: View {
    let title: String
    let items: [PickerItem<Kind>]
    var onPick: (Kind) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(title)
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                ForEach(items) { item in
                    Button {
                        onPick(item.kind)
                        dismiss()
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(Color.subtextAccent)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle().fill(Color.subtextAccent.opacity(0.15))
                                )
                            Text(item.displayName)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            GlassSurface(prominence: .interactive, cornerRadius: 14) { Color.clear }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(26)
        .frame(width: 520)
    }
}

struct PickerItem<Kind: Hashable & Identifiable>: Identifiable {
    var id: String
    var kind: Kind
    var displayName: String
    var systemImage: String
}
