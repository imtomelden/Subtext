import SwiftUI

enum SubtextBadgeTone {
    case neutral, accent, warning, danger, success
}

/// Unified badge/pill component replacing ad-hoc pill implementations throughout the app.
struct SubtextBadge: View {
    enum Style {
        /// Hides at 0, shows a 7pt dot at 1, shows a numbered capsule at 2+.
        case count(Int)
        /// A solid 7pt filled circle.
        case dot
        /// A text label in a subtle tinted capsule.
        case label(String)
        /// An icon + text status pill (e.g. autosave indicator).
        case status(String, icon: String? = nil)
    }

    let style: Style
    let tone: SubtextBadgeTone

    init(_ style: Style, tone: SubtextBadgeTone = .accent) {
        self.style = style
        self.tone = tone
    }

    var body: some View {
        switch style {
        case .count(let n):
            countBadge(n)
        case .dot:
            dotView
        case .label(let text):
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(textColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(fillColor.opacity(0.15)))
        case .status(let text, let icon):
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(text)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(fillColor.opacity(0.12)))
        }
    }

    @ViewBuilder
    private func countBadge(_ n: Int) -> some View {
        switch n {
        case 0:
            EmptyView()
        case 1:
            dotView
        default:
            Text("\(n)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: false))
                .animation(Motion.snappy, value: n)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(fillColor))
                .accessibilityLabel("\(n) items")
        }
    }

    private var dotView: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 7, height: 7)
    }

    private var fillColor: Color {
        switch tone {
        case .neutral:  Color.subtextSubtleFill
        case .accent:   Color.subtextAccent
        case .warning:  Color.subtextWarning
        case .danger:   Color.subtextDanger
        case .success:  Tokens.State.success
        }
    }

    private var textColor: Color {
        switch tone {
        case .neutral:  Tokens.Text.secondary
        case .accent:   Tokens.Accent.subtleText
        case .warning:  Tokens.State.warning
        case .danger:   Tokens.State.danger
        case .success:  Tokens.State.success
        }
    }
}
