import SwiftUI

enum SubtextUI {
    enum Glass {
        static let shellCornerRadius: CGFloat = 14
        static let panelCornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 0.7
        static let regularBorderOpacity: CGFloat = 0.16
        static let interactiveBorderOpacity: CGFloat = 0.22
        static let thickBorderOpacity: CGFloat = 0.26
        static let regularShadowOpacity: CGFloat = 0.05
        static let thickShadowOpacity: CGFloat = 0.1
        static let shadowRadius: CGFloat = 10
        static let shadowYOffset: CGFloat = 2
    }

    enum Typography {
        static let title = Font.title3.weight(.semibold)
        static let body = Font.callout
        static let bodyStrong = Font.callout.weight(.medium)
        static let caption = Font.caption
        static let captionMuted = Font.caption2
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }
}

/// Thin wrapper that applies Liquid Glass on macOS 26 and degrades to a
/// simple material on earlier OSes. Every surface in the app uses this so we
/// can tune the look in one place.
struct GlassSurface<Content: View>: View {
    enum Prominence {
        case regular
        case interactive
        case thick

        #if canImport(AppKit)
        fileprivate var material: NSVisualEffectView.Material {
            switch self {
            case .regular: .hudWindow
            case .interactive: .sidebar
            case .thick: .windowBackground
            }
        }
        #endif
    }

    let prominence: Prominence
    let cornerRadius: CGFloat
    @ViewBuilder var content: () -> Content

    init(
        prominence: Prominence = .regular,
        cornerRadius: CGFloat = SubtextUI.Glass.shellCornerRadius,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.prominence = prominence
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: SubtextUI.Glass.borderWidth)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    .mask {
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            .shadow(
                color: .black.opacity(prominence == .thick ? SubtextUI.Glass.thickShadowOpacity : SubtextUI.Glass.regularShadowOpacity),
                radius: SubtextUI.Glass.shadowRadius,
                y: SubtextUI.Glass.shadowYOffset
            )
    }

    @ViewBuilder
    private var background: some View {
        if #available(macOS 26.0, *) {
            glassBackground
        } else {
            fallbackBackground
        }
    }

    @available(macOS 26.0, *)
    @ViewBuilder
    private var glassBackground: some View {
        // Native Liquid Glass where the API is available; materials remain the
        // fallback on older macOS (see `fallbackBackground`).
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch prominence {
        case .regular:
            shape
                .fill(Color.clear)
                .glassEffect(.regular, in: shape)
        case .interactive:
            shape
                .fill(Color.clear)
                .glassEffect(.regular.interactive(), in: shape)
        case .thick:
            shape
                .fill(Color.clear)
                .glassEffect(.regular, in: shape)
        }
    }

    private var fallbackBackground: some View {
        VisualEffect(material: prominence.material, blendingMode: .behindWindow)
    }

    private var borderColor: Color {
        switch prominence {
        case .regular: Color.white.opacity(SubtextUI.Glass.regularBorderOpacity)
        case .interactive: Color.white.opacity(SubtextUI.Glass.interactiveBorderOpacity)
        case .thick: Color.white.opacity(SubtextUI.Glass.thickBorderOpacity)
        }
    }
}

#if canImport(AppKit)
/// NSVisualEffectView bridge — used as a direct Liquid Glass fallback where
/// `.glassEffect()` behaviour is missing or incomplete.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#endif

extension Color {
    /// Brand teal used site-wide, tuned per appearance for readability.
    static let subtextAccent: Color = {
        #if canImport(AppKit)
        return Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark {
                    // Slightly brighter in dark mode for icon and badge contrast.
                    return NSColor(
                        red: 0x3A / 255.0,
                        green: 0xB8 / 255.0,
                        blue: 0x8F / 255.0,
                        alpha: 1.0
                    )
                }
                return NSColor(
                    red: 0x1F / 255.0,
                    green: 0x8A / 255.0,
                    blue: 0x66 / 255.0,
                    alpha: 1.0
                )
            }
        )
        #else
        return Color(red: 0x1F / 255.0, green: 0x8A / 255.0, blue: 0x66 / 255.0)
        #endif
    }()

    /// Warning tint for draft-state affordances and reversible risks.
    static let subtextWarning = Color.orange

    /// Destructive tint for trash / delete actions.
    static let subtextDanger = Color.red

    /// Fill used behind neutral pills (e.g. counts). Thin enough to work on
    /// both glass and solid chrome.
    static let subtextSubtleFill = Color.secondary.opacity(0.18)
}

/// Ownership colors for project cards and badges.
extension ProjectFrontmatter.Ownership {
    var tint: Color {
        switch self {
        case .work: Color(red: 0.36, green: 0.83, blue: 0.64)
        case .personal: Color(red: 0.55, green: 0.45, blue: 0.95)
        }
    }
}
