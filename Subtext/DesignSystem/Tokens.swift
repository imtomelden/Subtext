import SwiftUI
import AppKit

/// Semantic design tokens for the Linear-inspired Subtext UI.
///
/// All colours are appearance-aware and resolve automatically in both light
/// and dark mode. Add new tokens here rather than using raw hex values or
/// `Color.primary.opacity(...)` hacks elsewhere in the codebase.
///
/// Usage: `Tokens.Background.canvas`, `Tokens.Border.subtle`, etc.
enum Tokens {

    // MARK: - Backgrounds

    enum Background {
        /// Outermost layer — window chrome, column fills, large canvas areas.
        static let canvas   = dynamic(light: 0xFFFFFF, dark: 0x08090A)
        /// Default surface for cards and content panels.
        static let surface  = dynamic(light: 0xFAFAFA, dark: 0x101113)
        /// Slightly elevated content (inspector, block editors).
        static let elevated = dynamic(light: 0xFFFFFF, dark: 0x18191C)
        /// Recessed wells — search fields, code blocks, text inputs.
        static let sunken   = dynamic(light: 0xF4F4F5, dark: 0x050506)
        /// High-opacity overlay for popovers and modals.
        static let overlay  = dynamic(light: 0xFFFFFF, dark: 0x0E0F11, al: 0.98, ad: 0.96)
    }

    // MARK: - Borders

    enum Border {
        /// Hairline divider and card outline — barely visible.
        static let subtle  = dynamic(light: 0xECECEE, dark: 0x1C1D20)
        /// Default border for interactive elements and form fields.
        static let `default` = dynamic(light: 0xE1E1E4, dark: 0x232428)
        /// Strong border for prominent or focused states.
        static let strong  = dynamic(light: 0xC9C9CD, dark: 0x2E2F33)
        /// Focus ring — accent at reduced opacity.
        static let focus   = Color.subtextAccent.opacity(0.55)
        /// Sidebar trailing edge.
        static let sidebar  = dynamic(light: 0xEBEBEB, dark: 0x222228)
        /// Project list column trailing edge.
        static let list     = dynamic(light: 0xEBEBEB, dark: 0x1C1C22)
        /// Meta chip and expanded block panel stroke.
        static let metaCard = dynamic(light: 0xEDEDED, dark: 0x222230)
    }

    // MARK: - Fills

    enum Fill {
        /// Sidebar and titlebar background.
        static let sidebar  = dynamic(light: 0xF7F7F7, dark: 0x111114)
        /// Meta chips, expanded block panels, settings group cards.
        static let metaCard = dynamic(light: 0xF9F9F9, dark: 0x161620)
        /// Tag chips, count badges.
        static let tag      = dynamic(light: 0xEDEDED, dark: 0x1E1E26)
    }

    // MARK: - Text

    enum Text {
        static let primary   = dynamic(light: 0x18181B, dark: 0xF4F4F5)
        static let secondary = dynamic(light: 0x52525B, dark: 0xB8B8B8)
        static let tertiary  = dynamic(light: 0x71717A, dark: 0x6E6E6E)
        static let disabled  = dynamic(light: 0xA1A1AA, dark: 0x52525B)
        static let onAccent  = dynamic(light: 0xFFFFFF, dark: 0x06120E)
    }

    // MARK: - Accent (teal, resolved from existing brand colour)

    enum Accent {
        /// Primary brand teal.
        static let `default`  = Color.subtextAccent
        /// Subtle background fill behind accent-tinted elements.
        static let subtleFill = Color.subtextAccent.opacity(0.10)
        /// Muted teal for secondary text on light/dark.
        static let subtleText = dynamic(light: 0x155E45, dark: 0x66D4AC)
    }

    // MARK: - State colours

    enum State {
        static let success = dynamic(light: 0x16A34A, dark: 0x22C55E)
        static let warning = dynamic(light: 0xD97706, dark: 0xF59E0B)
        static let danger  = dynamic(light: 0xDC2626, dark: 0xEF4444)
        static let info    = dynamic(light: 0x2563EB, dark: 0x3B82F6)
    }

    // MARK: - Helpers

    /// Build an appearance-aware `Color` from light/dark hex values.
    static func dynamic(
        light: UInt32,
        dark: UInt32,
        al: CGFloat = 1,  // alpha for light mode
        ad: CGFloat = 1   // alpha for dark mode
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(tokenHex: dark, alpha: ad)
                : NSColor(tokenHex: light, alpha: al)
        })
    }
}

// MARK: - NSColor hex convenience (Tokens-private)

extension NSColor {
    /// Initialise from a 6-digit RGB hex value, e.g. `NSColor(tokenHex: 0x1F8A66)`.
    convenience init(tokenHex hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8)  & 0xFF) / 255
        let b = CGFloat(hex         & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}
