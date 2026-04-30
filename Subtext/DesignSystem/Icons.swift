import SwiftUI

/// Named icon size tiers — consistent SF Symbol sizing and weight across the app.
enum IconSize {
    /// 10pt — micro indicators, tiny inline glyphs.
    case micro
    /// 12pt — caption-level icons, badge adornments.
    case small
    /// 14pt .medium — default body icon size.
    case body
    /// 16pt — section headings, list leading icons.
    case title
    /// 20pt .semibold — hero or empty-state icons.
    case hero

    var pointSize: CGFloat {
        switch self {
        case .micro:  10
        case .small:  12
        case .body:   14
        case .title:  16
        case .hero:   20
        }
    }

    var defaultWeight: Font.Weight {
        switch self {
        case .micro:  .regular
        case .small:  .regular
        case .body:   .medium
        case .title:  .medium
        case .hero:   .semibold
        }
    }
}

extension View {
    /// Apply consistent Subtext icon sizing, weight, and color.
    func subtextIcon(
        size: IconSize = .body,
        weight: Font.Weight? = nil,
        color: Color? = nil
    ) -> some View {
        self
            .font(.system(size: size.pointSize, weight: weight ?? size.defaultWeight))
            .foregroundStyle(color ?? Tokens.Text.secondary)
    }
}
