import SwiftUI

/// Scrollable log viewer for the publish pipeline (save → build → commit →
/// push). Uses the same monospace log layout as the Dev Server window.
struct PublishLogSheet: View {
    @Environment(PublishController.self) private var publish
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(18)

            Divider()

            logBody
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Publish log")
                    .font(.title3.weight(.semibold))
                Text(publish.phase.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder
    private var logBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(publish.log.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }
                }
                .padding(14)
            }
            .background(.quaternary.opacity(0.22))
            .onChange(of: publish.log.count) { _, newValue in
                guard newValue > 0 else { return }
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo(newValue - 1, anchor: .bottom)
                }
            }
        }
    }
}
