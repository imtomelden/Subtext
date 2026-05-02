import SwiftUI

/// Canonical motion vocabulary for Subtext.
///
/// Lifted out of `SlidingPanel.swift` so every surface — buttons, lists,
/// modals, drag, focus mode — pulls from a single set of timings and
/// springs. Keep this file the only source of `Animation` constants;
/// view code should never instantiate `.easeOut(...)` or `.spring(...)`
/// inline.
///
/// Naming convention:
/// - Duration tokens (`micro`/`short`/`medium`) describe linear-ish easing
///   for state flips and small layout changes.
/// - Spring tokens (`spring`/`bouncy`/`snappy`/`drag`) describe physical
///   responses for direct manipulation and reveal.
/// Source-compatibility shim. Older call sites refer to motion tokens via
/// `UXMotion`; new code should reference `Motion` directly.
typealias UXMotion = Motion

enum Motion {
    // MARK: - Legacy duration constants (kept for source compatibility)

    static let navigationDuration: Double = 0.12
    static let editorSwapDuration: Double = 0.10
    /// Panel reveal / drawer transition duration. Matches `short`.
    static let panelDuration: Double = 0.14

    // MARK: - Duration-based easings

    /// No animation — for hover and focus-ring state changes.
    static let instant: Animation? = nil
    /// 80 ms — chip toggles, button taps, small state flips.
    static let micro: Animation = .easeOut(duration: 0.08)
    /// 140 ms — panel reveals, drawer transitions, list inserts.
    static let short: Animation = .easeOut(duration: 0.14)
    /// 200 ms — route transitions (list ↔ editor), large layout changes.
    static let medium: Animation = .easeOut(duration: 0.20)

    // MARK: - Springs

    /// Default spring — panel reveals, inspector toggle, drawer transitions.
    static let spring: Animation = .spring(duration: 0.25, bounce: 0.12)
    /// Interactive spring with a touch of bounce — selection lifts, modal
    /// scale-in, peer displacement during drag-reorder.
    static let bouncy: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    /// Tight, responsive spring — focus glow, badge count change, hover lift.
    static let snappy: Animation = .spring(response: 0.20, dampingFraction: 0.8)
    /// Interpolating spring tuned for gesture follow during a drag. Use on
    /// the dragged item itself; use `bouncy` for peers being displaced.
    static let drag: Animation = .interpolatingSpring(stiffness: 320, damping: 28)

    // MARK: - Helpers

    static func easeInOut(duration: Double) -> Animation {
        .easeOut(duration: duration)
    }

    /// Stagger animation for list entrance. Pass the item's index; the
    /// `base` animation is delayed by `index * step` seconds.
    ///
    ///     ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ///         Row(item)
    ///             .staggeredAppear(index: index)
    ///     }
    static func stagger(
        index: Int,
        base: Animation = .easeOut(duration: 0.18),
        step: Double = 0.025,
        cap: Int = 12
    ) -> Animation {
        let clamped = min(max(index, 0), cap)
        return base.delay(Double(clamped) * step)
    }
}
