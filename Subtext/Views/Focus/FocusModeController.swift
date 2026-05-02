import SwiftUI

/// Single source of truth for focus mode across all editor surfaces.
///
/// Injected into the view hierarchy from `ContentView` as an `@Observable`
/// environment object. Views read it via `@Environment(FocusModeController.self)`.
///
/// `.writing` is full focus — sidebar collapsed, inspector hidden, toolbar
/// chrome faded, typewriter scroll active in the body editor.
/// `.reading` is sidebar-only collapse (lighter distraction reduction).
@Observable
final class FocusModeController {
    var isOn: Bool = false
    var level: Level = .writing

    enum Level {
        case reading   // sidebar only
        case writing   // sidebar + chrome fade + typewriter scroll
    }

    func toggle() {
        withAnimation(Motion.medium) { isOn.toggle() }
    }

    func cycleLevel() {
        withAnimation(Motion.medium) {
            level = level == .writing ? .reading : .writing
        }
    }
}

// MARK: - Chrome fade modifier

/// Fades and blurs non-essential chrome when focus mode is `.writing`.
///
/// Usage:
///     toolbar.focusModeChrome()  // fades to invisible in writing focus
///     sidebar.focusModeChrome(opacity: 0.35)  // partial fade for reading
struct FocusChromeModifier: ViewModifier {
    @Environment(FocusModeController.self) private var focusMode
    var fadedOpacity: CGFloat

    func body(content: Content) -> some View {
        let fullyHidden = focusMode.isOn && focusMode.level == .writing
        content
            .opacity(fullyHidden ? fadedOpacity : 1)
            .blur(radius: fullyHidden ? 3 : 0)
            .allowsHitTesting(!fullyHidden)
            .animation(Motion.medium, value: focusMode.isOn)
            .animation(Motion.medium, value: focusMode.level == .writing)
    }
}

extension View {
    /// Fades this view to `opacity` (default 0) when focus mode is active.
    func focusModeChrome(opacity: CGFloat = 0) -> some View {
        modifier(FocusChromeModifier(fadedOpacity: opacity))
    }
}
