import SwiftUI

/// A subtle, slowly-animated gradient layer placed behind all window content.
///
/// The animation is driven by SwiftUI's perpetual `withAnimation` — no
/// `TimelineView` or `CADisplayLink` needed. Opacity is intentionally low
/// (≤ 10%) so the effect reads as a tinted atmosphere rather than a visible
/// gradient. Glass surfaces blur and mix it further, which is the intent.
///
/// Automatically paused when `accessibilityReduceMotion` is enabled or
/// when the ambient style is `.none`.
struct AmbientBackground: View {
    let style: Theme.AmbientStyle

    @State private var phase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if style != .none && !reduceMotion {
            gradient
                .opacity(0.09)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 22).repeatForever(autoreverses: true)) {
                        phase = 1
                    }
                }
                .onChange(of: style) { _, _ in
                    // Reset and restart when style changes.
                    phase = 0
                    withAnimation(.linear(duration: 22).repeatForever(autoreverses: true)) {
                        phase = 1
                    }
                }
        }
    }

    @ViewBuilder
    private var gradient: some View {
        switch style {
        case .none:
            Color.clear

        case .aurora:
            // Shifting blue-green teal — mimics aurora borealis at very low opacity.
            LinearGradient(
                colors: [
                    Color(hue: 0.47 + phase * 0.07, saturation: 0.65, brightness: 0.80),
                    Color(hue: 0.56 + phase * 0.04, saturation: 0.50, brightness: 0.88),
                    Color(hue: 0.36 - phase * 0.04, saturation: 0.40, brightness: 0.82),
                ],
                startPoint: UnitPoint(x: phase * 0.3, y: 0),
                endPoint: UnitPoint(x: 1 - phase * 0.2, y: 1)
            )

        case .dusk:
            // Warm purple-to-peach sunset gradient.
            LinearGradient(
                colors: [
                    Color(hue: 0.74 + phase * 0.05, saturation: 0.55, brightness: 0.72),
                    Color(hue: 0.06 + phase * 0.04, saturation: 0.62, brightness: 0.92),
                ],
                startPoint: UnitPoint(x: 0.1 + phase * 0.1, y: 0),
                endPoint: UnitPoint(x: 0.9, y: 1)
            )

        case .warmPaper:
            // Near-white warm beige — barely perceptible tint for focus mode use.
            LinearGradient(
                colors: [
                    Color(hue: 0.09 + phase * 0.02, saturation: 0.18, brightness: 0.96),
                    Color(hue: 0.07, saturation: 0.12, brightness: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
