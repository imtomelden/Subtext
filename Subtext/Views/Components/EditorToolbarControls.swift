import AppKit
import SwiftUI

/// Small icon-only button that opens a file or folder in Finder.
/// Used across the Home / Projects / Settings toolbars.
struct RevealInFinderButton: View {
    let url: URL
    var helpText: String = "Reveal in Finder"

    var body: some View {
        Button {
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
            }
        } label: {
            Image(systemName: "folder")
        }
        .buttonStyle(.bordered)
        .help(helpText)
        .accessibilityLabel(helpText)
    }
}

/// Dev-server control in the sidebar footer — phase pill, primary action, window, preview, browser.
struct DevServerControl: View {
    @Environment(DevServerController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    private var defaultPort: Int {
        controller.lastKnownPort ?? RepoConstants.devServerURL.port ?? 4321
    }

    private var treatment: DevServerPhaseVisuals.Treatment {
        DevServerPhaseVisuals.treatment(phase: controller.phase, defaultPort: defaultPort)
    }

    var body: some View {
        HStack(spacing: 8) {
            DevServerStatusPill(
                phase: controller.phase,
                compact: false,
                defaultPort: defaultPort,
                onTap: { openWindow(id: "subtext-devserver") }
            )

            Spacer(minLength: 4)

            sidebarPrimaryControl(treatment: treatment)

            iconControlButton(
                systemName: "chevron.right.circle",
                helpText: DevServerPhaseVisuals.openDevServerWindowHelp(),
                accessibilityHint: DevServerPhaseVisuals.openDevServerWindowHelp()
            ) {
                openWindow(id: "subtext-devserver")
            }

            iconControlButton(
                systemName: "rectangle.stack",
                helpText: DevServerPhaseVisuals.livePreviewHelp(),
                accessibilityHint: DevServerPhaseVisuals.livePreviewHelp()
            ) {
                openWindow(id: "subtext-preview")
            }

            if controller.phase.isRunning {
                let port = controller.phase.displayPort ?? defaultPort
                iconControlButton(
                    systemName: "safari",
                    helpText: DevServerPhaseVisuals.openInBrowserHelp(port: port),
                    accessibilityHint: DevServerPhaseVisuals.openInBrowserHelp(port: port)
                ) {
                    if let url = URL(string: controller.devServerURLString) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        )
    }

    @ViewBuilder
    private func sidebarPrimaryControl(treatment: DevServerPhaseVisuals.Treatment) -> some View {
        switch controller.phase {
        case .preflighting, .starting:
            iconControlButton(
                systemName: treatment.primarySystemImage,
                helpText: treatment.primaryHelp,
                accessibilityHint: treatment.primaryHint
            ) {
                controller.cancelStart()
            }
        case .running:
            iconControlButton(
                systemName: treatment.primarySystemImage,
                helpText: treatment.primaryHelp,
                accessibilityHint: treatment.primaryHint
            ) {
                controller.stop()
            }
            .foregroundStyle(.red)
        case .stopping, .restarting:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 22, height: 18)
            .help(treatment.primaryHelp)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(treatment.primaryTitle)
            .accessibilityHint(treatment.primaryHint)
        case .stopped, .failed:
            iconControlButton(
                systemName: treatment.primarySystemImage,
                helpText: treatment.primaryHelp,
                accessibilityHint: treatment.primaryHint
            ) {
                controller.start()
            }
        }
    }

    @ViewBuilder
    private func iconControlButton(
        systemName: String,
        helpText: String,
        accessibilityHint: String = "",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(helpText)
        .accessibilityLabel(helpText)
        .accessibilityHint(accessibilityHint)
    }
}
