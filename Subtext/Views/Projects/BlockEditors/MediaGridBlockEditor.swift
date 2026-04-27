import SwiftUI

struct MediaGalleryBlockEditor: View {
    @Binding var block: MediaGalleryBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Title") {
                TextField("Section title", text: $block.title)
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(block.items.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 10) {
                        MediaThumbnail(src: block.items[safe: idx]?.src ?? "")

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("/images/...", text: src(at: idx))
                                .textFieldStyle(.roundedBorder)
                            TextField("Alt text", text: alt(at: idx))
                                .textFieldStyle(.roundedBorder)
                            TextField("Caption (optional)", text: caption(at: idx))
                                .textFieldStyle(.roundedBorder)
                            TextField("Source/Credit (optional)", text: credit(at: idx))
                                .textFieldStyle(.roundedBorder)
                            TextField("Date (optional, YYYY-MM-DD)", text: date(at: idx))
                                .textFieldStyle(.roundedBorder)
                            TextField("Location (optional)", text: location(at: idx))
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(role: .destructive) {
                            block.items.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(SubtextUI.Surface.subtleFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small))
                }

                Button {
                    block.items.append(.init(src: "", alt: "", caption: nil, credit: nil, date: nil, location: nil))
                } label: {
                    Label("Add media", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.subtextAccent)
            }
        }
    }

    private func src(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.src ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].src = v } }
        )
    }
    private func alt(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.alt ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].alt = v } }
        )
    }
    private func caption(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.caption ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].caption = v.isEmpty ? nil : v } }
        )
    }
    private func credit(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.credit ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].credit = v.isEmpty ? nil : v } }
        )
    }
    private func date(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.date ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].date = v.isEmpty ? nil : v } }
        )
    }
    private func location(at idx: Int) -> Binding<String> {
        Binding(
            get: { block.items[safe: idx]?.location ?? "" },
            set: { v in if idx < block.items.count { block.items[idx].location = v.isEmpty ? nil : v } }
        )
    }
}

/// Resolves a relative image path against `/public` for a quick preview.
private struct MediaThumbnail: View {
    let src: String

    var body: some View {
        Group {
            if let url = resolvedURL,
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous))
        .background(SubtextUI.Surface.subtleFill, in: RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous))
    }

    private var resolvedURL: URL? {
        guard !src.isEmpty else { return nil }
        if src.hasPrefix("http") { return nil }
        let trimmed = src.hasPrefix("/") ? String(src.dropFirst()) : src
        return RepoConstants.publicDirectory.appending(path: trimmed, directoryHint: .notDirectory)
    }
}
