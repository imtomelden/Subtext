import SwiftUI

/// Read-only source preview drawer. Shows either the current splash.json or
/// the active project's serialised MDX — useful for sanity-checking what
/// will be written to disk before hitting Save.
///
/// Phase 3 also references the CodeEditSourceEditor SPM package for syntax
/// highlighting. If/when added, swap the inner `Text` with its editor; the
/// rest of the drawer chrome stays the same.
struct SourcePreviewDrawer: View {
    enum Source {
        case splash(SplashContent)
        case project(ProjectDocument)
        case site(SiteSettings)
    }

    let source: Source
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(serialised, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help("Copy serialised source")

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .help("Reveal in Finder")

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(SubtextUI.Spacing.large + 2)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: SubtextUI.Spacing.small + 2) {
                    if hasSerialisationError {
                        Label("Source could not be encoded cleanly. Showing fallback text.", systemImage: "exclamationmark.triangle.fill")
                            .font(SubtextUI.Typography.caption)
                            .foregroundStyle(Color.subtextWarning)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                                    .fill(SubtextUI.Surface.warningBannerFill)
                            )
                    }

                    Text(serialised)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(SubtextUI.Spacing.large + 2)
            }
            .background(
                GlassSurface(prominence: .interactive, cornerRadius: 0) { Color.clear }
            )
        }
        .frame(minWidth: 520, minHeight: 480)
    }

    private var fileURL: URL {
        switch source {
        case .splash: RepoConstants.splashFile
        case .site: RepoConstants.siteFile
        case .project(let p):
            RepoConstants.projectsDirectory
                .appending(path: p.fileName, directoryHint: .notDirectory)
        }
    }

    private var title: String {
        switch source {
        case .splash: "splash.json preview"
        case .project(let p): "\(p.fileName) preview"
        case .site: "site.json preview"
        }
    }

    private var subtitle: String {
        switch source {
        case .splash: RepoConstants.splashFile.path(percentEncoded: false)
        case .site: RepoConstants.siteFile.path(percentEncoded: false)
        case .project(let p):
            RepoConstants.projectsDirectory
                .appending(path: p.fileName, directoryHint: .notDirectory)
                .path(percentEncoded: false)
        }
    }

    private var serialised: String {
        switch source {
        case .splash(let splash):
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(splash), let s = String(data: data, encoding: .utf8) {
                return s
            }
            return "// Failed to encode splash.json"
        case .site(let site):
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(site), let s = String(data: data, encoding: .utf8) {
                return s
            }
            return "// Failed to encode site.json"
        case .project(let doc):
            return MDXSerialiser.serialise(doc)
        }
    }

    private var hasSerialisationError: Bool {
        switch source {
        case .project:
            return false
        case .splash, .site:
            return serialised.hasPrefix("// Failed to encode")
        }
    }
}
