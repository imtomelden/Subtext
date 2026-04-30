import SwiftUI

enum UXMotion {
    static let navigationDuration: Double = 0.12
    static let editorSwapDuration: Double = 0.10
    /// Panel reveal / drawer transition duration. Matches `short`.
    static let panelDuration: Double = 0.14

    // MARK: - Linear-style motion vocabulary

    /// No animation — for hover and focus-ring state changes.
    static let instant: Animation? = nil
    /// 80 ms — chip toggles, button taps, small state flips.
    static let micro: Animation = .easeOut(duration: 0.08)
    /// 140 ms — panel reveals, drawer transitions, list inserts.
    static let short: Animation = .easeOut(duration: 0.14)
    /// 200 ms — route transitions (list ↔ editor), large layout changes.
    static let medium: Animation = .easeOut(duration: 0.20)
    /// Spring — panel reveals, inspector toggle, drawer transitions.
    static let spring: Animation = .spring(duration: 0.25, bounce: 0.12)

    static func easeInOut(duration: Double) -> Animation {
        .easeOut(duration: duration)
    }
}

/// Right-side detail panel that appears alongside the canvas.
///
/// Uses a straightforward `animation(_:value:)` approach with no coalescing
/// queue — state changes take effect immediately so the panel feels instant.
struct SlidingPanel<Panel: View>: ViewModifier {
    let isPresented: Bool
    let width: CGFloat
    let panel: () -> Panel

    init(
        isPresented: Bool,
        width: CGFloat = RepoConstants.detailPanelWidth,
        @ViewBuilder panel: @escaping () -> Panel
    ) {
        self.isPresented = isPresented
        self.width = width
        self.panel = panel
    }

    func body(content: Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isPresented {
                GlassSurface(prominence: .thick, cornerRadius: 20) {
                    panel()
                        .frame(width: width)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(width: width)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.vertical, 12)
                .padding(.trailing, 12)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing)
                ))
                .accessibilityElement(children: .contain)
            }
        }
        .animation(UXMotion.spring, value: isPresented)
    }
}

extension View {
    func slidingPanel<P: View>(
        isPresented: Bool,
        width: CGFloat = RepoConstants.detailPanelWidth,
        @ViewBuilder content: @escaping () -> P
    ) -> some View {
        modifier(SlidingPanel(isPresented: isPresented, width: width, panel: content))
    }
}
