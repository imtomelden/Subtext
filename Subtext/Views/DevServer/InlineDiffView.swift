import SwiftUI

/// Displays the raw unified diff for a single changed file.
/// Lines prefixed with `+` are tinted green, `-` red, `@@` muted blue.
struct InlineDiffView: View {
    let path: String

    @Environment(GitController.self) private var git
    @State private var diffText: String? = nil
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Diff content
            ScrollView([.vertical, .horizontal]) {
                if isLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Loading diff…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                } else if let diff = diffText, !diff.isEmpty {
                    diffContent(diff)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("New untracked file — no diff available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                }
            }
            .frame(minHeight: 120, maxHeight: 320)
        }
        .frame(width: 560)
        .task {
            isLoading = true
            diffText = await git.diff(path: path)
            isLoading = false
        }
    }

    @ViewBuilder
    private func diffContent(_ raw: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(raw.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                diffLine(line)
            }
        }
    }

    @ViewBuilder
    private func diffLine(_ line: String) -> some View {
        let style = lineStyle(line)
        Text(line.isEmpty ? " " : line)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(style.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 0.5)
            .background(style.background)
    }

    private struct LineStyle {
        var foreground: Color
        var background: Color
    }

    private func lineStyle(_ line: String) -> LineStyle {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return LineStyle(
                foreground: Color(nsColor: .systemGreen),
                background: Color(nsColor: .systemGreen).opacity(0.10)
            )
        }
        if line.hasPrefix("-") && !line.hasPrefix("---") {
            return LineStyle(
                foreground: Color(nsColor: .systemRed),
                background: Color(nsColor: .systemRed).opacity(0.10)
            )
        }
        if line.hasPrefix("@@") {
            return LineStyle(
                foreground: Color(nsColor: .systemBlue).opacity(0.8),
                background: Color(nsColor: .systemBlue).opacity(0.06)
            )
        }
        if line.hasPrefix("diff ") || line.hasPrefix("index ") || line.hasPrefix("---") || line.hasPrefix("+++") {
            return LineStyle(foreground: .secondary, background: .clear)
        }
        return LineStyle(foreground: Tokens.Text.primary, background: .clear)
    }
}
