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
            TextField("Optional subtitle", text: Binding(
                get: { section.subtitle ?? "" },
                set: { section.subtitle = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }

        FieldRow("Body paragraphs") {
            StringListEditor(
                items: $section.bodyParagraphs,
                placeholder: "Paragraph text",
                addLabel: "Add paragraph",
                multiline: true
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
