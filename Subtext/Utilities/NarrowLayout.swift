import SwiftUI

/// Window-width breakpoints used by horizontal panels (project list,
/// inspector) so they can shrink — or hide — on small displays such as a
/// 13" MacBook Air. Populated once near the root of the detail view via
/// `onGeometryChange`, then consumed throughout the view tree via
/// `@Environment(\.narrowLayout)`.
struct NarrowLayout: Equatable, Sendable {
    /// `true` when the available width is below the comfortable threshold.
    /// Panels should shrink, but stay visible.
    var isNarrow: Bool

    /// `true` when width is so constrained that secondary panels (e.g. the
    /// project inspector) should auto-hide on first appearance.
    var isVeryNarrow: Bool

    static let normal = NarrowLayout(isNarrow: false, isVeryNarrow: false)

    /// Shrink panels below this width.
    static let narrowBreakpoint: CGFloat = 1280

    /// Auto-hide secondary panels below this width.
    static let veryNarrowBreakpoint: CGFloat = 1100

    static func from(width: CGFloat) -> NarrowLayout {
        NarrowLayout(
            isNarrow: width < narrowBreakpoint,
            isVeryNarrow: width < veryNarrowBreakpoint
        )
    }
}

private struct NarrowLayoutKey: EnvironmentKey {
    static let defaultValue = NarrowLayout.normal
}

extension EnvironmentValues {
    var narrowLayout: NarrowLayout {
        get { self[NarrowLayoutKey.self] }
        set { self[NarrowLayoutKey.self] = newValue }
    }
}
