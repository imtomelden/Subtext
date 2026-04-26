import AppKit
import SwiftUI

/// Handles NSWindow-level chrome for the main window only. SwiftUI cannot
/// fully express a hidden-but-transparent title bar, traffic-light positioning,
/// and a clear content backing for the glass sidebar. Auxiliary windows (Dev
/// server, Live preview, etc.) must keep the default opaque background; applying
/// the same settings to every `NSWindow` made those surfaces look transparent.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            self.configureMainWindow()
        }
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .subtextAppWillTerminate, object: nil)
    }

    private func configureMainWindow() {
        for window in NSApplication.shared.windows {
            guard Self.isMainSubtextWindow(window) else { continue }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
        }
    }

    /// Matches the title passed to `Window("Subtext", id: "subtext-main")`.
    private static func isMainSubtextWindow(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == "subtext-main" { return true }
        return window.title == "Subtext"
    }
}
