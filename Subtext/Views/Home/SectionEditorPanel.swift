import AppKit
import SwiftUI

struct SectionEditorPanel: View {
    @Binding var section: SplashSection
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    commonFields
                    Divider().padding(.vertical, 6)
                    visualFields
                }
                .padding(20)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: section.sectionSystemImage)
                .font(.title3)
                .foregroundStyle(Color.subtextAccent)

            VStack(alignment: .leading, spacing: 0) {
                Text(section.heading.isEmpty ? "Untitled section" : section.heading)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text("\(section.sectionLabel) · \(section.visual.kind.displayName) visual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    @ViewBuilder
    private var commonFields: some View {
        FieldRow("Heading") {
            TextField("Heading", text: $section.heading)
                .textFieldStyle(.roundedBorder)
        }

        FieldRow("Subtitle") {
            HomeMarkdownFieldSection(
                text: Binding(
                    get: { section.subtitle ?? "" },
                    set: { section.subtitle = $0.isEmpty ? nil : $0 }
                ),
                minHeight: 120
            )
        }

        FieldRow("Body Markdown") {
            HomeMarkdownFieldSection(
                text: Binding(
                    get: { joinMarkdownParagraphsSection(section.bodyParagraphs) },
                    set: { section.bodyParagraphs = splitMarkdownParagraphsSection($0) }
                ),
                minHeight: 220
            )
        }

        FieldRow("Image position") {
            Picker("", selection: $section.imagePosition) {
                ForEach(SplashSection.ImagePosition.allCases) { pos in
                    Text(pos.displayName).tag(pos)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }

        Toggle(isOn: $section.isHero) {
            Label("Mark as hero section", systemImage: "crown.fill")
        }
    }

    @ViewBuilder
    private var visualFields: some View {
        Text("Visual")
            .font(.caption)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)

        switch section.visual {
        case .photo:
            PhotoVisualEditor(visual: visualBinding())
        case .ticket:
            TicketVisualEditor(visual: visualBinding())
        case .speech:
            SpeechVisualEditor(visual: visualBinding())
        case .scramble:
            ScrambleVisualEditor(visual: visualBinding())
        case .terminal:
            TerminalVisualEditor(visual: visualBinding())
        case .clapper:
            ClapperVisualEditor(visual: visualBinding())
        }
    }

    private func visualBinding() -> Binding<VisualContent> {
        Binding(
            get: { section.visual },
            set: { section.visual = $0 }
        )
    }
}

private struct HomeMarkdownFieldSection: View {
    @Binding var text: String
    var minHeight: CGFloat = 140

    @State private var selection: NSRange = NSRange(location: 0, length: 0)
    @State private var contentHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownInsertToolbar(text: $text, selection: $selection)
            MarkdownSourceEditor(
                text: $text,
                selection: $selection,
                font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                contentHeight: $contentHeight
            )
            .frame(height: max(minHeight, contentHeight))
            .clipShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.medium, style: .continuous))
        }
    }
}

private func joinMarkdownParagraphsSection(_ paragraphs: [String]) -> String {
    paragraphs.joined(separator: "\n\n")
}

private func splitMarkdownParagraphsSection(_ markdown: String) -> [String] {
    let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
    let parts = normalized.components(separatedBy: .newlines)
    var blocks: [String] = []
    var buffer: [String] = []

    func flushBuffer() {
        let block = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !block.isEmpty {
            blocks.append(block)
        }
        buffer.removeAll(keepingCapacity: true)
    }

    for line in parts {
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            flushBuffer()
        } else {
            buffer.append(line)
        }
    }
    flushBuffer()

    return blocks
}

struct CTAEditorPanel: View {
    @Binding var cta: SplashCTA
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.braille.fill")
                    .font(.title3)
                    .foregroundStyle(Color.subtextAccent)
                Text("CTA — \(cta.name)")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FieldRow("Internal name") {
                        TextField("e.g. Projects CTA", text: $cta.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    FieldRow("Heading") {
                        TextField("Heading", text: $cta.heading)
                            .textFieldStyle(.roundedBorder)
                    }
                    FieldRow("Subtitle") {
                        TextField("Subtitle", text: $cta.subtitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    FieldRow("Link URL") {
                        TextField("https://…", text: $cta.href)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(20)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
}
