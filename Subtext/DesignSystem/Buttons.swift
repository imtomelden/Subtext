import SwiftUI
import AppKit

enum SubtextButtonVariant {
    /// Accent fill, white text — primary call-to-action.
    case primary
    /// Elevated fill with border, primary text — secondary actions.
    case secondary
    /// Clear fill, secondary text that shifts to accent on hover — low-emphasis.
    case ghost
    /// Danger-tinted fill and border — destructive or irreversible actions.
    case destructive
    /// 28×28 icon-only hit area, no background — toolbar and inline icon buttons.
    case icon
}

struct SubtextButtonStyle: ButtonStyle {
    let variant: SubtextButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        InnerBody(configuration: configuration, variant: variant)
    }

    private struct InnerBody: View {
        let configuration: ButtonStyleConfiguration
        let variant: SubtextButtonVariant
        @State private var isHovered = false

        var body: some View {
            styled(configuration.label)
                .opacity(configuration.isPressed ? 0.80 : 1)
                .animation(UXMotion.instant, value: configuration.isPressed)
                .onHover { hovering in
                    isHovered = hovering
                    if variant == .icon {
                        if hovering { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
                }
                .animation(UXMotion.instant, value: isHovered)
        }

        @ViewBuilder
        private func styled(_ label: some View) -> some View {
            switch variant {
            case .primary:
                label
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                            .fill(isHovered ? Color.subtextAccent.opacity(0.88) : Color.subtextAccent)
                    )

            case .secondary:
                label
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Tokens.Text.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                            .fill(isHovered ? Tokens.Background.surface : Tokens.Background.elevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                            .strokeBorder(Tokens.Border.default, lineWidth: 0.5)
                    )

            case .ghost:
                label
                    .font(.callout)
                    .foregroundStyle(isHovered ? Color.subtextAccent : Tokens.Text.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)

            case .destructive:
                label
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Tokens.State.danger)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                            .fill(Tokens.State.danger.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                            .strokeBorder(Tokens.State.danger.opacity(0.35), lineWidth: 0.5)
                    )

            case .icon:
                label
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isHovered ? Color.subtextAccent : Tokens.Text.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
        }
    }
}

extension View {
    /// Apply a named Subtext button appearance. Replaces `buttonStyle(.borderedProminent).tint(...)`.
    func subtextButton(_ variant: SubtextButtonVariant) -> some View {
        buttonStyle(SubtextButtonStyle(variant: variant))
    }
}

/// Icon button with an optional active state that tints to accent color.
struct IconButton: View {
    let icon: String
    var isActive: Bool = false
    var tooltip: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(isActive ? Color.subtextAccent : Tokens.Text.secondary)
        }
        .subtextButton(.icon)
        .help(tooltip)
    }
}
