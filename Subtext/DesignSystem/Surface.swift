import SwiftUI

/// A flat, non-blurring surface view that replaces `GlassSurface(.flat)` for
/// all content panels — block cards, the editor canvas, input wells, etc.
///
/// Chrome surfaces (sidebar, toasts, command palette, sliding panels) should
/// continue to use `GlassSurface` with an appropriate prominence.
///
/// Usage:
/// ```swift
/// Surface(.surface) {
///     Text("Hello")
///         .padding()
/// }
/// ```
struct Surface<Content: View>: View {

    enum Style {
        /// Matches the window/column background — used for the editor canvas.
        case canvas
        /// Default card / panel surface. Use for blocks, body editor sections.
        case surface
        /// Slightly elevated card — for content inside an already-elevated panel.
        case elevated
        /// Recessed well — for search fields, text inputs, code areas.
        case sunken
    }

    let style: Style
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        _ style: Style,
        cornerRadius: CGFloat = SubtextUI.Radius.xLarge,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
    }

    // MARK: - Private

    private var fillColor: Color {
        switch style {
        case .canvas:   return Tokens.Background.canvas
        case .surface:  return Tokens.Background.surface
        case .elevated: return Tokens.Background.elevated
        case .sunken:   return Tokens.Background.sunken
        }
    }

    private var borderColor: Color {
        switch style {
        case .canvas:   return .clear
        case .surface:  return Tokens.Border.subtle
        case .elevated: return Tokens.Border.subtle
        case .sunken:   return Tokens.Border.default
        }
    }
}
