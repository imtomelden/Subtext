import SwiftUI

// MARK: - Press Ripple

/// Radial ripple that plays on press. Apply via `.pressRipple(isPressed:)` inside
/// a custom ButtonStyle where you already have `configuration.isPressed`.
struct PressRippleModifier: ViewModifier {
    let isPressed: Bool
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                let side = max(geo.size.width, geo.size.height) * 1.6
                Circle()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: side, height: side)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .scaleEffect(scale)
            }
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous))
        )
        .onChange(of: isPressed) { _, pressed in
            guard pressed else { return }
            scale = 0.6
            opacity = 0.22
            withAnimation(.easeOut(duration: 0.38)) {
                scale = 1
                opacity = 0
            }
        }
    }
}

extension View {
    func pressRipple(isPressed: Bool) -> some View {
        modifier(PressRippleModifier(isPressed: isPressed))
    }
}

// MARK: - Hover Lift

/// Subtle scale + shadow that lifts a card on hover. Use on block cards and
/// other interactive surfaces — not on flat backgrounds.
struct HoverLiftModifier: ViewModifier {
    @State private var isHovered = false
    var scale: CGFloat = 1.005
    var shadowRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .shadow(
                color: isHovered ? Color.black.opacity(0.07) : .clear,
                radius: isHovered ? shadowRadius : 0,
                x: 0, y: isHovered ? 2 : 0
            )
            .onHover { isHovered = $0 }
            .animation(Motion.snappy, value: isHovered)
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.005, shadowRadius: CGFloat = 6) -> some View {
        modifier(HoverLiftModifier(scale: scale, shadowRadius: shadowRadius))
    }
}

// MARK: - Number Roll

/// Text view that animates count changes with a numeric slide transition.
/// Use in place of `Text("\(count)")` wherever a count can increment or decrement.
struct NumberRoll: View {
    let value: Int
    var font: Font = .caption2.weight(.bold).monospacedDigit()
    var color: Color = .white

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(countsDown: false))
            .animation(Motion.snappy, value: value)
    }
}

// MARK: - Toggle Bounce

/// Wraps a view so it performs a brief scale bounce when `trigger` flips.
/// Useful for icon buttons that toggle state (e.g. inspector, focus mode).
struct ToggleBounceModifier: ViewModifier {
    let trigger: Bool
    @State private var bouncing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(bouncing ? 1.25 : 1.0)
            .onChange(of: trigger) { _, _ in
                withAnimation(Motion.bouncy) { bouncing = true }
                withAnimation(Motion.bouncy.delay(0.12)) { bouncing = false }
            }
    }
}

extension View {
    func toggleBounce(trigger: Bool) -> some View {
        modifier(ToggleBounceModifier(trigger: trigger))
    }
}
