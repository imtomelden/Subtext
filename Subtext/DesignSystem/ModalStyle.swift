import SwiftUI

/// Visual treatment for a `subtextModal` presentation.
///
/// - `command`: Bare presentation — the content provides its own glass
///   surface (used by `CommandPalette` which already wraps itself in
///   `GlassSurface`). Backed by a semi-transparent dimmed backdrop.
/// - `glassCard`: The modal system wraps content in a `GlassSurface` with
///   optional fixed dimensions. Backed by a dimmed backdrop.
enum ModalStyle {
    /// Content supplies its own chrome; the host only provides backdrop + animation.
    case command

    /// Host wraps content in a `GlassSurface` card.
    /// Pass `nil` dimensions to let the card size itself to its content.
    case glassCard(width: CGFloat? = nil, height: CGFloat? = nil)
}
