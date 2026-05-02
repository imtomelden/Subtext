import SwiftUI

/// Reusable `AnyTransition` values + view modifiers, paired with `Motion`.
///
/// All transitions defined here are intentionally small and composable —
/// callers combine them via `.combined(with:)` rather than us baking every
/// permutation. Use these instead of inline `.move(...)` / `.opacity` so
/// the motion language stays consistent across surfaces.
extension AnyTransition {
    /// Soft rise: 8pt vertical offset + opacity. Good for list inserts and
    /// modal content within an already-animated container.
    static var subtextRise: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 8).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Scale-in from 96% with opacity. Matches the modal & overlay
    /// presentation feel — pair with `Motion.bouncy`.
    static var subtextScale: AnyTransition {
        .scale(scale: 0.96).combined(with: .opacity)
    }

    /// Blur-in transition (6pt → 0). Use sparingly; pairs with focus mode
    /// chrome fades and with backdrop reveals.
    static var subtextBlur: AnyTransition {
        .modifier(
            active: BlurTransitionModifier(radius: 6, opacity: 0),
            identity: BlurTransitionModifier(radius: 0, opacity: 1)
        )
    }

    /// Slide from a specific edge with opacity on insert; pure slide on
    /// removal (matches existing `SlidingPanel` removal feel).
    static func subtextSlideEdge(_ edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .move(edge: edge)
        )
    }
}

/// Internal modifier backing `.subtextBlur`.
private struct BlurTransitionModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
    }
}

extension View {
    /// Animates the view's appearance with a staggered delay derived from
    /// `index`. The view starts offset (8pt) + transparent and settles into
    /// place using `Motion.stagger`.
    ///
    /// Cap defaults to 12 so a 1000-row list does not produce a 25s wave.
    func staggeredAppear(index: Int, step: Double = 0.025, cap: Int = 12) -> some View {
        modifier(StaggeredAppearModifier(index: index, step: step, cap: cap))
    }
}

private struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let step: Double
    let cap: Int

    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 8)
            .onAppear {
                withAnimation(Motion.stagger(index: index, step: step, cap: cap)) {
                    hasAppeared = true
                }
            }
    }
}
