import AppKit
import SwiftUI

struct TerminalVisualEditor: View {
    @Binding var visual: VisualContent
    @State private var previewExpanded = true

    private var terminalModel: TerminalVisual {
        if case .terminal(let t) = visual { return t }
        return TerminalVisual(title: "", lines: [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Window title") {
                SubtextTextField("e.g. tinkerer.js", text: titleBinding)
            }
            FieldRow("Lines") {
                StringListEditor(
                    items: linesBinding,
                    placeholder: "Line text",
                    addLabel: "Add line"
                )
            }

            DisclosureGroup(isExpanded: $previewExpanded) {
                TerminalBlockPreview(title: terminalModel.title, lines: terminalModel.lines)
                    .padding(.top, 6)
            } label: {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.subtextAccent)
            }
            .animation(Motion.snappy, value: previewExpanded)
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: {
                if case .terminal(let t) = visual { return t.title }
                return ""
            },
            set: { newValue in
                guard case .terminal(var t) = visual else { return }
                t.title = newValue
                visual = .terminal(t)
            }
        )
    }

    private var linesBinding: Binding<[String]> {
        Binding(
            get: {
                if case .terminal(let t) = visual { return t.lines }
                return []
            },
            set: { newValue in
                guard case .terminal(var t) = visual else { return }
                t.lines = newValue
                visual = .terminal(t)
            }
        )
    }
}

private struct TerminalBlockPreview: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color.red.opacity(0.9)).frame(width: 8, height: 8)
                Circle().fill(Color.yellow.opacity(0.9)).frame(width: 8, height: 8)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 8, height: 8)
                Text(title.isEmpty ? "window" : title)
                    .font(.caption2.monospaced().weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    let displayLines = lines.map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }.filter { !$0.isEmpty }
                    if displayLines.isEmpty {
                        terminalLine("$ ")
                    } else {
                        ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                            terminalLine("$ \(line)")
                        }
                        terminalLine("$ ")
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            .background(Color(red: 0.09, green: 0.10, blue: 0.12))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func terminalLine(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(Color(red: 0.82, green: 0.86, blue: 0.82))
            .multilineTextAlignment(.leading)
    }
}
