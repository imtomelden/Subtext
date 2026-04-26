import SwiftUI

/// Right-side detail panel that sits on the same layout plane as the canvas.
///
/// This intentionally avoids overlay and edge-slide motion so editing feels
/// like stable side-by-side columns, with only the left-most app sidebar
/// behaving as the distinct navigation column.
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
        HStack(alignment: .top, spacing: 12) {
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
                .accessibilityElement(children: .contain)
            }
        }
        .animation(.easeInOut(duration: 0.14), value: isPresented)
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
