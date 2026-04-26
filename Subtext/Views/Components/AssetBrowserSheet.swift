import AppKit
import SwiftUI

/// Grid browser for everything under `/public/images`. Search filters by
/// path and filename; clicking an asset copies its website-relative path to
/// the clipboard so it can be pasted into an AssetPathField.
///
/// Read-only on purpose — we never mutate the filesystem from here. Drag
/// targets + rename live in a future slice.
struct AssetBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var assets: [AssetAudit.AssetEntry] = []
    @State private var loading: Bool = true
    @State private var query: String = ""
    @State private var selection: AssetAudit.AssetEntry.ID?
    private let audit = AssetAudit()

    private let columns: [GridItem] = Array(
        repeating: GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12),
        count: 1
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()

            content
        }
        .frame(width: 720, height: 560)
        .task { await reload() }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Assets").font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [RepoConstants.publicDirectory.appending(path: "images", directoryHint: .isDirectory)]
                )
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .help("Reveal /public/images in Finder")

            Button {
                Task { await reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(loading)

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var subtitle: String {
        if loading { return "Scanning /public/images…" }
        let total = assets.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return "\(assets.count) file\(assets.count == 1 ? "" : "s") • \(ByteFormatter.string(for: total))"
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter by path or filename", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: query.isEmpty ? "photo.stack" : "questionmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(query.isEmpty ? "No assets under /public/images yet." : "No assets match “\(query)”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filtered) { asset in
                        AssetTile(
                            asset: asset,
                            isSelected: selection == asset.id
                        )
                        .onTapGesture {
                            selection = asset.id
                        }
                        .contextMenu {
                            Button("Copy path") { copyPath(asset) }
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([asset.url])
                            }
                        }
                        .onTapGesture(count: 2) {
                            copyPath(asset)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var filtered: [AssetAudit.AssetEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return assets }
        return assets.filter { $0.relativePath.lowercased().contains(q) }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        let found = await audit.enumerateAssets()
        self.assets = found
    }

    private func copyPath(_ asset: AssetAudit.AssetEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(asset.relativePath, forType: .string)
    }
}

private struct AssetTile: View {
    let asset: AssetAudit.AssetEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AssetThumbnail(src: asset.relativePath, size: 120, cornerRadius: 10)
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.subtextAccent : Color.clear,
                            lineWidth: 2
                        )
                )

            Text(asset.fileName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(metadataLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.subtextAccent.opacity(0.10) : .clear)
        )
        .help(asset.relativePath + "\n\nDouble-click to copy path")
    }

    private var metadataLine: String {
        var parts: [String] = [ByteFormatter.string(for: asset.sizeBytes)]
        if let size = asset.pixelSize {
            parts.append("\(Int(size.width))×\(Int(size.height))")
        }
        return parts.joined(separator: " · ")
    }
}
