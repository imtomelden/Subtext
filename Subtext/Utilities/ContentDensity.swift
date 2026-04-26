import SwiftUI

/// Layout density for list-style surfaces (Home, Projects).
enum ContentDensity: String, CaseIterable, Sendable {
    case comfortable
    case compact

    var sectionOuterSpacing: CGFloat {
        switch self {
        case .comfortable: SubtextUI.Spacing.xLarge
        case .compact: SubtextUI.Spacing.large
        }
    }

    var canvasTopPadding: CGFloat {
        switch self {
        case .comfortable: SubtextUI.Spacing.xLarge
        case .compact: SubtextUI.Spacing.large
        }
    }

    var listRowSpacing: CGFloat {
        switch self {
        case .comfortable: SubtextUI.Spacing.small
        case .compact: SubtextUI.Spacing.xSmall
        }
    }
}

private enum ContentDensityKey: EnvironmentKey {
    static let defaultValue: ContentDensity = .comfortable
}

extension EnvironmentValues {
    var contentDensity: ContentDensity {
        get { self[ContentDensityKey.self] }
        set { self[ContentDensityKey.self] = newValue }
    }
}
