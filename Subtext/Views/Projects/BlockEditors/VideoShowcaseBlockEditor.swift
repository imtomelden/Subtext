import SwiftUI

struct VideoShowcaseBlockEditor: View {
    @Binding var block: VideoShowcaseBlock
    @State private var ctaExpanded = false
    @State private var sourceDetailsExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Variant") {
                Picker("", selection: $block.variant) {
                    ForEach(VideoShowcaseBlock.Variant.allCases) { v in
                        Text(v.displayName).tag(v)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            FieldRow("Description") {
                TextField("Optional description", text: Binding(
                    get: { block.description ?? "" },
                    set: { block.description = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            }

            FieldRow("Highlights") {
                StringListEditor(
                    items: $block.highlights,
                    placeholder: "Highlight",
                    addLabel: "Add highlight"
                )
            }

            FieldRow("Video source") {
                sourceEditor
            }

            DisclosureGroup("Call to action", isExpanded: $ctaExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    FieldRow("CTA text") {
                        TextField("Optional CTA text", text: Binding(
                            get: { block.ctaText ?? "" },
                            set: { block.ctaText = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    FieldRow("CTA link") {
                        TextField("Optional CTA href", text: Binding(
                            get: { block.ctaHref ?? "" },
                            set: { block.ctaHref = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: sourceKindBinding) {
                Text("YouTube").tag(SourceKind.youtube)
                Text("Vimeo").tag(SourceKind.vimeo)
                Text("File").tag(SourceKind.file)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            DisclosureGroup("Source details", isExpanded: $sourceDetailsExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    switch block.source {
                    case .youtube:
                        TextField("YouTube video ID", text: videoIDBinding)
                            .textFieldStyle(.roundedBorder)
                        Label("Preview uses YouTube embed on the website.", systemImage: "play.rectangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case .vimeo:
                        TextField("Vimeo video ID", text: vimeoIDBinding)
                            .textFieldStyle(.roundedBorder)
                        Label("Preview uses Vimeo embed on the website.", systemImage: "play.rectangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case .file:
                        FieldRow("Video file") {
                            AssetPathField(path: fileSrcBinding, placeholder: "/videos/... or https://...")
                        }
                        FieldRow("Poster") {
                            AssetPathField(path: posterBinding, placeholder: "/images/... (optional)")
                        }
                        FieldRow("MIME type") {
                            TextField("video/mp4 (optional)", text: mimeTypeBinding)
                                .textFieldStyle(.roundedBorder)
                        }
                        FieldRow("Fallback URL") {
                            TextField("Optional fallback URL", text: fallbackURLBinding)
                                .textFieldStyle(.roundedBorder)
                        }
                        FieldRow("Captions") {
                            captionEditor
                        }
                    }
                }
                .padding(.top, 8)
            }

            sourcePreview
        }
        .padding(10)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private enum SourceKind: Hashable { case youtube, vimeo, file }

    private var sourceKindBinding: Binding<SourceKind> {
        Binding(
            get: {
                switch block.source {
                case .youtube: .youtube
                case .vimeo: .vimeo
                case .file: .file
                }
            },
            set: { newKind in
                switch newKind {
                case .youtube:
                    block.source = .youtube(videoId: extractCurrentVideoID() ?? "")
                case .vimeo:
                    block.source = .vimeo(videoId: extractCurrentVideoID() ?? "")
                case .file:
                    if case .file = block.source { return }
                    block.source = .file(src: "", poster: nil, mimeType: nil, fallbackUrl: nil, captions: [])
                }
            }
        )
    }

    private var videoIDBinding: Binding<String> {
        Binding(
            get: {
                if case .youtube(let id) = block.source { return id }
                return ""
            },
            set: { newValue in
                let normalized = normalizeYouTubeInput(newValue)
                block.source = .youtube(videoId: normalized)
            }
        )
    }

    private var vimeoIDBinding: Binding<String> {
        Binding(
            get: {
                if case .vimeo(let id) = block.source { return id }
                return ""
            },
            set: { newValue in
                let normalized = normalizeVimeoInput(newValue)
                block.source = .vimeo(videoId: normalized)
            }
        )
    }

    private var fileSrcBinding: Binding<String> {
        Binding(
            get: {
                if case .file(let src, _, _, _, _) = block.source { return src }
                return ""
            },
            set: { newSrc in
                let details = fileDetails()
                block.source = .file(
                    src: newSrc,
                    poster: details.poster,
                    mimeType: details.mimeType,
                    fallbackUrl: details.fallbackUrl,
                    captions: details.captions
                )
            }
        )
    }

    private var posterBinding: Binding<String> {
        Binding(
            get: {
                if case .file(_, let p, _, _, _) = block.source { return p ?? "" }
                return ""
            },
            set: { newPoster in
                let details = fileDetails()
                block.source = .file(
                    src: details.src,
                    poster: newPoster.isEmpty ? nil : newPoster,
                    mimeType: details.mimeType,
                    fallbackUrl: details.fallbackUrl,
                    captions: details.captions
                )
            }
        )
    }

    private var mimeTypeBinding: Binding<String> {
        Binding(
            get: {
                if case .file(_, _, let mimeType, _, _) = block.source { return mimeType ?? "" }
                return ""
            },
            set: { newValue in
                let details = fileDetails()
                block.source = .file(
                    src: details.src,
                    poster: details.poster,
                    mimeType: newValue.isEmpty ? nil : newValue,
                    fallbackUrl: details.fallbackUrl,
                    captions: details.captions
                )
            }
        )
    }

    private var fallbackURLBinding: Binding<String> {
        Binding(
            get: {
                if case .file(_, _, _, let fallbackUrl, _) = block.source { return fallbackUrl ?? "" }
                return ""
            },
            set: { newValue in
                let details = fileDetails()
                block.source = .file(
                    src: details.src,
                    poster: details.poster,
                    mimeType: details.mimeType,
                    fallbackUrl: newValue.isEmpty ? nil : newValue,
                    captions: details.captions
                )
            }
        )
    }

    private var captionsBinding: Binding<[VideoShowcaseBlock.CaptionTrack]> {
        Binding(
            get: {
                if case .file(_, _, _, _, let captions) = block.source { return captions }
                return []
            },
            set: { newCaptions in
                let details = fileDetails()
                block.source = .file(
                    src: details.src,
                    poster: details.poster,
                    mimeType: details.mimeType,
                    fallbackUrl: details.fallbackUrl,
                    captions: newCaptions
                )
            }
        )
    }

    @ViewBuilder
    private var captionEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(captionsBinding.wrappedValue.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Track \(index + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            var captions = captionsBinding.wrappedValue
                            captions.remove(at: index)
                            captionsBinding.wrappedValue = captions
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    TextField("Caption file path / URL", text: captionBinding(index: index, keyPath: \.src))
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        TextField("Language (e.g. en)", text: captionBinding(index: index, keyPath: \.srclang))
                            .textFieldStyle(.roundedBorder)
                        TextField("Label", text: captionBinding(index: index, keyPath: \.label))
                            .textFieldStyle(.roundedBorder)
                    }
                    Toggle("Default track", isOn: captionDefaultBinding(index: index))
                        .toggleStyle(.switch)
                }
                .padding(8)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                var captions = captionsBinding.wrappedValue
                captions.append(.init(src: "", srclang: "en", label: "English", isDefault: captions.isEmpty))
                captionsBinding.wrappedValue = captions
            } label: {
                Label("Add caption track", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var sourcePreview: some View {
        switch block.source {
        case .youtube(let videoId):
            embedSourcePreview(
                idLabel: videoId.isEmpty ? "No YouTube ID set yet." : "YouTube ID: \(videoId)"
            )
        case .vimeo(let videoId):
            embedSourcePreview(
                idLabel: videoId.isEmpty ? "No Vimeo ID set yet." : "Vimeo ID: \(videoId)"
            )
        case .file(let src, let poster, _, _, _):
            HStack(spacing: 10) {
                AssetMediaThumbnail(src: poster ?? src, size: 52, cornerRadius: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(src.isEmpty ? "No file selected yet." : src)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let poster, !poster.isEmpty {
                        Text("Poster set")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func embedSourcePreview(idLabel: String) -> some View {
        Label(idLabel, systemImage: "play.rectangle.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func captionBinding(index: Int, keyPath: WritableKeyPath<VideoShowcaseBlock.CaptionTrack, String>) -> Binding<String> {
        Binding(
            get: {
                let captions = captionsBinding.wrappedValue
                guard captions.indices.contains(index) else { return "" }
                return captions[index][keyPath: keyPath]
            },
            set: { newValue in
                var captions = captionsBinding.wrappedValue
                guard captions.indices.contains(index) else { return }
                captions[index][keyPath: keyPath] = newValue
                captionsBinding.wrappedValue = captions
            }
        )
    }

    private func captionDefaultBinding(index: Int) -> Binding<Bool> {
        Binding(
            get: {
                let captions = captionsBinding.wrappedValue
                guard captions.indices.contains(index) else { return false }
                return captions[index].isDefault
            },
            set: { isDefault in
                var captions = captionsBinding.wrappedValue
                guard captions.indices.contains(index) else { return }
                if isDefault {
                    for idx in captions.indices {
                        captions[idx].isDefault = idx == index
                    }
                } else {
                    captions[index].isDefault = false
                }
                captionsBinding.wrappedValue = captions
            }
        )
    }

    private func fileDetails() -> (
        src: String,
        poster: String?,
        mimeType: String?,
        fallbackUrl: String?,
        captions: [VideoShowcaseBlock.CaptionTrack]
    ) {
        if case .file(let src, let poster, let mimeType, let fallbackUrl, let captions) = block.source {
            return (src, poster, mimeType, fallbackUrl, captions)
        }
        return ("", nil, nil, nil, [])
    }

    private func extractCurrentVideoID() -> String? {
        switch block.source {
        case .youtube(let id), .vimeo(let id):
            return id
        case .file:
            return nil
        }
    }

    private func normalizeYouTubeInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let extracted = extractYouTubeID(from: trimmed) {
            return extracted
        }
        return trimmed
    }

    private func extractYouTubeID(from input: String) -> String? {
        guard let url = URL(string: input),
              let host = url.host?.lowercased() else {
            return nil
        }

        if host.contains("youtu.be") {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.isEmpty ? nil : id
        }

        if host.contains("youtube.com") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
               !v.isEmpty {
                return v
            }

            let path = url.path.lowercased()
            if path.hasPrefix("/embed/") || path.hasPrefix("/shorts/") {
                let id = url.path.split(separator: "/").last.map(String.init) ?? ""
                return id.isEmpty ? nil : id
            }
        }

        return nil
    }

    private func normalizeVimeoInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let extracted = extractVimeoID(from: trimmed) {
            return extracted
        }
        return trimmed
    }

    private func extractVimeoID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.allSatisfy(\.isNumber) {
            return trimmed
        }

        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              host.contains("vimeo.com") else {
            return nil
        }

        let pathComponents = url.path.split(separator: "/").map(String.init)
        let candidate = pathComponents.last(where: { $0.allSatisfy(\.isNumber) })
        guard let candidate, !candidate.isEmpty else { return nil }
        return candidate
    }
}
