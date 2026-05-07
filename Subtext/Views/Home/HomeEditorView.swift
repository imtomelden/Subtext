import AppKit
import SwiftUI

struct HomeEditorView: View {
    @Environment(CMSStore.self) private var store
    @Environment(FocusModeController.self) private var focusMode

    @State private var showHistory = false
    @State private var showSourcePreview = false
    @State private var selection: NSRange = NSRange(location: 0, length: 0)
    @State private var editorHeight: CGFloat = 420

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let error = store.homeMarkdownError {
                    parseErrorBanner(error)
                }
                sourceToolbar
                sourceEditor
                if !focusMode.isOn {
                    hintLabel
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(isPresented: $showHistory) {
            HomeHistoryPanel()
        }
        .sheet(isPresented: $showSourcePreview) {
            SourcePreviewDrawer(source: .splash(store.splashContent)) {
                showSourcePreview = false
            }
        }
        .task(id: store.loadState == .loaded) {
            guard store.loadState == .loaded else { return }
            if store.homeMarkdownSource.isEmpty {
                store.syncHomeMarkdownFromSplash()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Home")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Tokens.Text.primary)
                    .tracking(-0.78)
                Text("Plain markdown Home writing. Save compiles this source to splash.json.")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            Spacer()
            HStack(spacing: 6) {
                AutosaveIndicator(
                    isDirty: store.isSplashDirty,
                    lastPersistedAt: store.lastDraftPersistedAt
                )
                RevealInFinderButton(
                    url: RepoConstants.splashFile,
                    helpText: "Reveal splash.json in Finder"
                )
                Button {
                    showSourcePreview = true
                } label: {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Preview compiled splash.json source")
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Version history")
            }
        }
    }

    private var sourceToolbar: some View {
        MarkdownInsertToolbar(text: markdownBinding, selection: $selection)
    }

    private var sourceEditor: some View {
        MarkdownSourceEditor(
            text: markdownBinding,
            selection: $selection,
            font: NSFont.systemFont(ofSize: NSFont.systemFontSize + 1),
            contentHeight: $editorHeight
        )
        .frame(height: editorHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.large, style: .continuous))
        .accessibilityLabel("Home markdown canvas")
    }

    private var hintLabel: some View {
        Text("Write sections as `## Heading` + body paragraphs. Add a `## CTAs` heading, then each CTA as `### Name`, a markdown link line, and subtitle text.")
            .font(.system(size: 10))
            .foregroundStyle(Tokens.Text.tertiary)
    }

    private var markdownBinding: Binding<String> {
        Binding(
            get: { store.homeMarkdownSource },
            set: { store.updateHomeMarkdownSource($0) }
        )
    }

    @ViewBuilder
    private func parseErrorBanner(_ error: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.subtextWarning)
            Text(error)
                .font(.callout)
                .foregroundStyle(Tokens.Text.primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            GlassSurface(prominence: .interactive, cornerRadius: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.subtextWarning.opacity(0.14))
            }
        )
    }
}
