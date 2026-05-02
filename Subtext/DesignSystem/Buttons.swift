import SwiftUI
import AppKit

// MARK: - Loading state

private enum SubtextButtonLoadingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// When true, `SubtextButtonStyle` shows a compact indeterminate progress view instead of the label.
    var subtextButtonIsLoading: Bool {
        get { self[SubtextButtonLoadingKey.self] }
        set { self[SubtextButtonLoadingKey.self] = newValue }
    }
}

extension View {
    /// Replaces the label with a spinner and ignores presses while `isLoading` is true.
    func subtextButtonLoading(_ isLoading: Bool) -> some View {
        environment(\.subtextButtonIsLoading, isLoading)
    }
}

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
        @Environment(\.subtextButtonIsLoading) private var isLoading
        @State private var isHovered = false

        var body: some View {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(variant == .primary || variant == .destructive ? .regular : .small)
                        .frame(minWidth: loadingMinWidth, minHeight: loadingMinHeight)
                } else {
                    styled(configuration.label)
                }
            }
                .scaleEffect(configuration.isPressed ? pressScale : (isHovered ? hoverScale : 1.0))
                .opacity(configuration.isPressed ? 0.88 : 1)
                .pressRipple(isPressed: configuration.isPressed && usesRipple && !isLoading)
                .animation(Motion.snappy, value: configuration.isPressed)
                .onHover { hovering in
                    isHovered = hovering
                    if variant == .icon {
                        if hovering { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
                }
                .animation(Motion.snappy, value: isHovered)
                .allowsHitTesting(!isLoading)
        }

        private var loadingMinWidth: CGFloat {
            switch variant {
            case .primary, .secondary, .destructive: 72
            case .ghost: 60
            case .icon: 28
            }
        }

        private var loadingMinHeight: CGFloat {
            switch variant {
            case .icon: 28
            default: 22
            }
        }

        private var pressScale: CGFloat {
            switch variant {
            case .primary, .secondary, .destructive: 0.97
            case .ghost: 0.98
            case .icon: 0.88
            }
        }

        private var hoverScale: CGFloat {
            switch variant {
            case .primary, .secondary, .destructive: 1.01
            case .ghost: 1.0
            case .icon: 1.10
            }
        }

        private var usesRipple: Bool {
            switch variant {
            case .primary, .secondary: true
            default: false
            }
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
                            .fill(isHovered ? Color.accentColor.opacity(0.88) : Color.accentColor)
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
                    .foregroundStyle(isHovered ? Color.accentColor : Tokens.Text.secondary)
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
                    .foregroundStyle(isHovered ? Color.accentColor : Tokens.Text.secondary)
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
                .foregroundStyle(isActive ? Color.accentColor : Tokens.Text.secondary)
        }
        .subtextButton(.icon)
        .help(tooltip)
    }
}
