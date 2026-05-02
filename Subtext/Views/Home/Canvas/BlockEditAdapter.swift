import SwiftUI

/// Inline form body for a `SplashSection`.
///
/// Contains the same field layout as `SectionEditorPanel` but without
/// a panel frame — used directly inside `SectionBlockHostView` when a
/// block is expanded for inline editing on the canvas.
struct SectionInlineEditor: View {
    @Binding var section: SplashSection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            commonFields
            Divider().padding(.vertical, 2)
            visualSection
        }
        .padding(20)
    }

    // MARK: - Common fields

    @ViewBuilder
    private var commonFields: some View {
        FieldRow("Heading") {
            SubtextTextField("Heading", text: $section.heading)
        }

        FieldRow("Subtitle") {
            SubtextTextField("Optional subtitle", text: Binding(
                get: { section.subtitle ?? "" },
                set: { section.subtitle = $0.isEmpty ? nil : $0 }
            ))
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
        .tint(Color.subtextAccent)
    }

    // MARK: - Visual fields

    @ViewBuilder
    private var visualSection: some View {
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

/// Inline form body for a `SplashCTA`.
///
/// Used inside `CTABlockHostView` when a CTA is expanded for inline
/// editing on the canvas.
struct CTAInlineEditor: View {
    @Binding var cta: SplashCTA

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FieldRow("Internal name") {
                SubtextTextField("e.g. Projects CTA", text: $cta.name)
            }
            FieldRow("Heading") {
                SubtextTextField("Heading", text: $cta.heading)
            }
            FieldRow("Subtitle") {
                SubtextTextField("Subtitle", text: $cta.subtitle)
            }
            FieldRow("Link URL") {
                SubtextTextField("https://…", text: $cta.href)
            }
        }
        .padding(20)
    }
}
