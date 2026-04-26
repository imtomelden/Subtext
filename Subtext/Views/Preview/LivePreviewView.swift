import AppKit
import SwiftUI
import WebKit

/// Standalone window that embeds a `WKWebView` pinned to the Astro dev
/// server (defaults to `http://localhost:4321`). Designed to sit alongside
/// the editor so every `⌘S` causes a visible re-render — closing the loop
/// on "does my edit actually reach the site" checks that previously
/// required a browser tab.
///
/// Deep-linking: the hash fragment follows the section ID the user last
/// clicked in `HomeEditorView`, so picking a section in Subtext scrolls
/// the preview to its matching anchor on the Astro page.
struct LivePreviewView: View {
    @Environment(CMSStore.self) private var store
    @Environment(DevServerController.self) private var devServer
    @Environment(\.openWindow) private var openWindow
    @State private var reloadToken: UUID = UUID()
    @State private var urlOverride: URL?

    private var liveBaseURL: URL {
        URL(string: devServer.devServerURLString) ?? RepoConstants.devServerURL
    }

    private var defaultPort: Int {
        devServer.lastKnownPort ?? RepoConstants.devServerURL.port ?? 4321
    }

    private var previewURL: URL {
        let target = urlOverride ?? liveBaseURL
        guard let sectionID = store.editingSectionID,
              var components = URLComponents(url: target, resolvingAgainstBaseURL: false) else {
            return target
        }
        components.fragment = sectionID
        return components.url ?? target
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial)

            Divider()

            if devServer.phase.isRunning {
                PreviewWebView(url: previewURL, reloadToken: reloadToken)
                    .frame(minWidth: 600, minHeight: 720)
            } else {
                devServerOffState
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 10) {
            DevServerStatusPill(
                phase: devServer.phase,
                compact: true,
                defaultPort: defaultPort,
                onTap: { openWindow(id: "subtext-devserver") }
            )

            Spacer()

            Text(previewURL.absoluteString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            if devServer.phase.isRunning {
                Button {
                    reloadToken = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Reload preview")

                Button {
                    NSWorkspace.shared.open(previewURL)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.bordered)
                .help("Open in default browser")
            }
        }
    }

    @ViewBuilder
    private var devServerOffState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Dev server isn't running")
                .font(.title3.weight(.semibold))
            Text("Open the Dev Server window to run preflight and start npm run dev. The preview connects when the server is running.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button {
                openWindow(id: "subtext-devserver")
            } label: {
                Label("Open Dev Server", systemImage: "gearshape.2")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.subtextAccent)
            .help(DevServerPhaseVisuals.openDevServerWindowHelp())
            .accessibilityHint(DevServerPhaseVisuals.openDevServerWindowHelp())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

/// Minimal SwiftUI wrapper around `WKWebView`. The `reloadToken` forces a
/// reload when its identity changes — used by the toolbar's reload button
/// and by external consumers (e.g. "just saved, refresh now").
struct PreviewWebView: NSViewRepresentable {
    let url: URL
    let reloadToken: UUID

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.setValue(false, forKey: "drawsBackground")
        context.coordinator.currentURL = url
        context.coordinator.currentToken = reloadToken
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let coord = context.coordinator
        let urlChanged = coord.currentURL != url
        let tokenChanged = coord.currentToken != reloadToken
        guard urlChanged || tokenChanged else { return }
        coord.currentURL = url
        coord.currentToken = reloadToken
        if urlChanged {
            view.load(URLRequest(url: url))
        } else {
            view.reloadFromOrigin()
        }
    }

    final class Coordinator {
        var currentURL: URL?
        var currentToken: UUID?
    }
}
