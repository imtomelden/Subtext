import SwiftUI

struct ClapperVisualEditor: View {
    @Binding var visual: VisualContent
    @State private var previewExpanded = true

    private var clapperModel: ClapperVisual {
        if case .clapper(let c) = visual { return c }
        return ClapperVisual(scene: "", take: "", roll: "", loc: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                FieldRow("Scene") {
                    SubtextTextField("e.g. 1", text: bind(\.scene))
                }
                FieldRow("Take") {
                    SubtextTextField("e.g. 1", text: bind(\.take))
                }
            }
            HStack(spacing: 12) {
                FieldRow("Roll") {
                    SubtextTextField("e.g. A", text: bind(\.roll))
                }
                FieldRow("Loc") {
                    SubtextTextField("e.g. Manchester", text: bind(\.loc))
                }
            }
            Text("The site shows today’s date (UK) next to location automatically; only Loc is stored here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            DisclosureGroup(isExpanded: $previewExpanded) {
                ClapperBlockPreview(scene: clapperModel.scene, take: clapperModel.take, roll: clapperModel.roll, loc: clapperModel.loc)
                    .padding(.top, 6)
            } label: {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.subtextAccent)
            }
            .animation(Motion.snappy, value: previewExpanded)
        }
    }

    private func bind(_ keyPath: WritableKeyPath<ClapperVisual, String>) -> Binding<String> {
        Binding(
            get: {
                if case .clapper(let c) = visual { return c[keyPath: keyPath] }
                return ""
            },
            set: { newValue in
                guard case .clapper(var c) = visual else { return }
                c[keyPath: keyPath] = newValue
                visual = .clapper(c)
            }
        )
    }
}

private struct ClapperBlockPreview: View {
    let scene: String
    let take: String
    let roll: String
    let loc: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.subtextAccent)
                .frame(width: 5)
                .overlay(alignment: .topTrailing) {
                    Text("STICK")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.45))
                        .rotationEffect(.degrees(-45))
                        .offset(x: 4, y: 22)
                        .tracking(0.4)
                }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    labelled("SCENE", value: scene, placeholder: "1")
                    labelled("TAKE", value: take, placeholder: "1")
                }
                .font(.caption2.monospaced().weight(.semibold))
                HStack(spacing: 14) {
                    labelled("ROLL", value: roll, placeholder: "A")
                    labelled("LOC", value: loc.isEmpty ? "—" : loc, placeholder: "")
                }
                .font(.caption2.monospaced().weight(.semibold))
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.caption.monospaced().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.subtextAccent.opacity(0.15))
                .strokeBorder(Color.subtextAccent.opacity(0.25), lineWidth: 1)
        )
    }

    private func labelled(_ title: String, value: String, placeholder: String) -> some View {
        let shown = value.isEmpty && !placeholder.isEmpty ? placeholder : value
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 8, weight: .heavy)).foregroundStyle(Color.subtextAccent)
            Text(shown.isEmpty ? "—" : shown)
                .foregroundStyle(Tokens.Text.primary)
        }
    }
}
