import SwiftUI

enum UXMotion {
    static let navigationDuration: Double = 0.16
    static let editorSwapDuration: Double = 0.12
    static let panelDuration: Double = 0.16

    static func easeInOut(duration: Double) -> Animation {
        .easeInOut(duration: duration)
    }
}

/// Coalesces rapid state changes while an animation is running so only the
/// latest requested target is applied once the current transition completes.
@MainActor
final class CoalescedTransitionQueue<Value: Equatable>: ObservableObject {
    private var inFlight = false
    private var pendingTarget: Value?
    private var completionTask: Task<Void, Never>?

    func reset() {
        completionTask?.cancel()
        completionTask = nil
        inFlight = false
        pendingTarget = nil
    }

    func run(
        to target: Value,
        duration: Double,
        current: @escaping () -> Value,
        perform: @escaping (Value) -> Void
    ) {
        if inFlight {
            pendingTarget = target
            return
        }
        guard current() != target else {
            pendingTarget = nil
            return
        }

        inFlight = true
        perform(target)
        scheduleCompletion(duration: duration, current: current, perform: perform)
    }

    private func scheduleCompletion(
        duration: Double,
        current: @escaping () -> Value,
        perform: @escaping (Value) -> Void
    ) {
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            let nanos = UInt64(max(duration, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            inFlight = false
            completionTask = nil

            guard let pending = pendingTarget else { return }
            pendingTarget = nil
            if pending != current() {
                run(to: pending, duration: duration, current: current, perform: perform)
            }
        }
    }
}

/// Right-side detail panel that sits on the same layout plane as the canvas.
///
/// This intentionally avoids overlay and edge-slide motion so editing feels
/// like stable side-by-side columns, with only the left-most app sidebar
/// behaving as the distinct navigation column.
struct SlidingPanel<Panel: View>: ViewModifier {
    let isPresented: Bool
    let width: CGFloat
    let panel: () -> Panel
    private let collapsedRailWidth: CGFloat = 20
    @State private var renderedIsPresented = false
    @StateObject private var transitionQueue = CoalescedTransitionQueue<Bool>()

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

            panelRail
                .frame(width: renderedIsPresented ? width : collapsedRailWidth, alignment: .trailing)
                .animation(UXMotion.easeInOut(duration: UXMotion.panelDuration), value: renderedIsPresented)
        }
        .onAppear {
            renderedIsPresented = isPresented
        }
        .onChange(of: isPresented) { _, newValue in
            transitionPresentation(to: newValue)
        }
        .onDisappear {
            transitionQueue.reset()
        }
    }

    @ViewBuilder
    private var panelRail: some View {
        ZStack(alignment: .trailing) {
            if renderedIsPresented {
                GlassSurface(prominence: .thick, cornerRadius: 20) {
                    panel()
                        .frame(width: width)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(width: width)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.vertical, 12)
                .padding(.trailing, 12)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }

            Capsule(style: .continuous)
                .fill(.quaternary.opacity(0.55))
                .frame(width: 4, height: 36)
                .padding(.trailing, 8)
                .opacity(renderedIsPresented ? 0 : 1)
                .accessibilityHidden(true)
        }
    }

    private func transitionPresentation(to target: Bool) {
        transitionQueue.run(
            to: target,
            duration: UXMotion.panelDuration,
            current: { renderedIsPresented }
        ) { next in
            withAnimation(UXMotion.easeInOut(duration: UXMotion.panelDuration)) {
                renderedIsPresented = next
            }
        }
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
