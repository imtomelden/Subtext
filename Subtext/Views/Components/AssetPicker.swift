import AppKit
import SwiftUI

/// Shared thumbnail that resolves a relative website path (e.g. `/images/x.png`)
/// against the Website repo's `/public` directory.
///
/// Renders an SF Symbol placeholder for empty / remote / missing paths.
struct AssetThumbnail: View {
    let src: String
    var size: CGFloat = 72
    var cornerRadius: CGFloat = 8
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if src.hasPrefix("http") {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(
            .quaternary.opacity(0.4),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .task(id: src) {
            await loadImage()
        }
    }

    /// Resolves a `src` string to a file URL under `/public`, or `nil` for
    /// empty/remote/unresolvable inputs.
    static func resolvedURL(for src: String) -> URL? {
        guard !src.isEmpty else { return nil }
        if src.hasPrefix("http") { return nil }
        let trimmed = src.hasPrefix("/") ? String(src.dropFirst()) : src
        return RepoConstants.publicDirectory.appending(path: trimmed, directoryHint: .notDirectory)
    }

    @MainActor
    private func loadImage() async {
        guard let url = Self.resolvedURL(for: src) else {
            image = nil
            return
        }
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }
        let loaded = await Task.detached(priority: .utility) { () -> NSImage? in
            guard let data = try? Data(contentsOf: url),
                  let decoded = NSImage(data: data) else { return nil }
            return decoded
        }.value
        if let loaded {
            Self.cache.setObject(loaded, forKey: url as NSURL)
        }
        image = loaded
    }

    private static let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 200
        return cache
    }()
}

/// Shared media preview that handles image and video paths.
/// For videos we use symbolic placeholders and path metadata, while image
/// rendering keeps using `AssetThumbnail`.
struct AssetMediaThumbnail: View {
    let src: String
    var size: CGFloat = 72
    var cornerRadius: CGFloat = 8

    var body: some View {
        if Self.isLikelyVideoPath(src) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.quaternary.opacity(0.4))
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: src.hasPrefix("http") ? "play.circle" : "film")
                            .font(.system(size: size * 0.28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(src.hasPrefix("http") ? "Remote video" : "Video")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(6)
                }
                .frame(width: size, height: size)
        } else {
            AssetThumbnail(src: src, size: size, cornerRadius: cornerRadius)
        }
    }

    static func isLikelyVideoPath(_ src: String) -> Bool {
        let lower = src.lowercased()
        return lower.hasSuffix(".mp4")
            || lower.hasSuffix(".mov")
            || lower.hasSuffix(".webm")
            || lower.hasSuffix(".m4v")
            || lower.hasSuffix(".m3u8")
    }
}

/// Labelled field combining a text input, a small live thumbnail, and a
/// "Choose…" button that opens an NSOpenPanel rooted at the website's
/// `/public` directory.
///
/// The on-disk value is always a website-relative path (`/images/foo.png`).
/// Absolute URLs and arbitrary strings are passed through unchanged so the
/// escape hatch still works for manually authored paths.
struct AssetPathField: View {
    @Binding var path: String
    var placeholder: String = "/images/… (optional)"

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AssetMediaThumbnail(src: path, size: 54, cornerRadius: 7)

            VStack(alignment: .leading, spacing: 6) {
                TextField(placeholder, text: $path)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button {
                        chooseFile()
                    } label: {
                        Label("Choose…", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if let url = AssetThumbnail.resolvedURL(for: path),
                       FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Label("Reveal", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !path.isEmpty {
                        Button(role: .destructive) {
                            path = ""
                        } label: {
                            Label("Clear", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .alert("File not inside /public", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = RepoConstants.publicDirectory
        panel.prompt = "Use path"
        panel.allowedContentTypes = [.image, .movie, .pdf]

        guard panel.runModal() == .OK, let chosen = panel.url else { return }

        let publicPath = RepoConstants.publicDirectory.path(percentEncoded: false)
        let chosenPath = chosen.path(percentEncoded: false)
        guard chosenPath.hasPrefix(publicPath) else {
            errorMessage = "Pick a file from /public so it resolves on the site.\n\n\(chosenPath)"
            showError = true
            return
        }
        let relative = String(chosenPath.dropFirst(publicPath.count))
        path = relative.hasPrefix("/") ? relative : "/" + relative
    }
}
