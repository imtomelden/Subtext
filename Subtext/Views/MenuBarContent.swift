import AppKit
import SwiftUI

/// Content of the system menu-bar extra. Shows dev-server status, unsaved
/// count, and quick actions to open the window, open the live preview,
/// or jump straight into the publish panel. Designed to be glanceable —
/// no edits happen here, just status and navigation.
struct MenuBarContent: View {
    @Environment(CMSStore.self) private var store
    @Environment(DevServerController.self) private var devServer
    @Environment(GitController.self) private var git
    @Environment(PublishController.self) private var publish
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusGrid
            Divider()
            actions
        }
        .padding(14)
        .frame(width: 300)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.append")
                .foregroundStyle(Color.subtextAccent)
            Text("Subtext")
                .font(.headline)
            Spacer()
            if publish.isBusy {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            }
        }
    }

    private var defaultDevPort: Int {
        devServer.lastKnownPort ?? RepoConstants.devServerURL.port ?? 4321
    }

    @ViewBuilder
    private var statusGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                DevServerStatusPill(
                    phase: devServer.phase,
                    compact: true,
                    defaultPort: defaultDevPort,
                    onTap: { openWindow(id: "subtext-devserver") }
                )
                Text(devServerValue)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            statusRow(
                systemImage: "link",
                tint: .secondary,
                label: "URL",
                value: devServer.devServerURLString
            )

            if let hint = devServer.conflictRecoveryHint {
                statusRow(
                    systemImage: "exclamationmark.triangle.fill",
                    tint: Color.subtextWarning,
                    label: "Conflict",
                    value: hint
                )
            }

            statusRow(
                systemImage: store.isAnyDirty ? "circle.fill" : "checkmark.circle",
                tint: store.isAnyDirty ? Color.subtextWarning : Color.subtextAccent,
                label: "Unsaved",
                value: unsavedValue
            )

            statusRow(
                systemImage: git.hasLocalChanges ? "arrow.triangle.branch" : "arrow.triangle.branch",
                tint: git.hasLocalChanges ? Color.subtextWarning : .secondary,
                label: "Branch",
                value: branchValue
            )

            if let err = store.lastError, !err.isEmpty {
                statusRow(
                    systemImage: "exclamationmark.triangle.fill",
                    tint: Color.subtextWarning,
                    label: "Last error",
                    value: err
                )
            }
        }
    }

    @ViewBuilder
    private func statusRow(
        systemImage: String,
        tint: Color,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(label == "Last error" ? 3 : 1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                openWindow(id: "subtext-main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Subtext app", systemImage: "macwindow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help("Bring the main Subtext window to front")

            Button {
                openWindow(id: "subtext-preview")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Live preview", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help(DevServerPhaseVisuals.livePreviewHelp())

            menuBarPrimaryDevAction

            Button {
                openWindow(id: "subtext-devserver")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Dev Server window…", systemImage: "gearshape.2")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help(DevServerPhaseVisuals.openDevServerWindowHelp())
            .accessibilityHint(DevServerPhaseVisuals.openDevServerWindowHelp())

            if devServer.phase.isRunning {
                let port = devServer.phase.displayPort ?? defaultDevPort
                Button {
                    if let url = URL(string: devServer.devServerURLString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open dev URL", systemImage: "safari")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .help(DevServerPhaseVisuals.openInBrowserHelp(port: port))
            }

            Button {
                openWindow(id: "subtext-main")
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .subtextOpenEventLog, object: nil)
            } label: {
                Label("Event log…", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help("Open the main window to the event log")

            Button {
                openWindow(id: "subtext-main")
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .subtextOpenGitPanel, object: nil)
            } label: {
                Label("Build & publish…", systemImage: "hammer")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help("Open the publish workflow")

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Subtext", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help("Quit Subtext")
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Values

    private var devServerValue: String {
        devServer.statusSummary
    }

    private var unsavedValue: String {
        guard store.isAnyDirty else { return "All saved" }
        var parts: [String] = []
        if store.isSplashDirty { parts.append("splash") }
        if store.isSiteDirty { parts.append("site") }
        let projectCount = store.projects.filter { store.isProjectDirty($0.fileName) }.count
        if projectCount > 0 {
            parts.append("\(projectCount) project\(projectCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private var branchValue: String {
        let branch = git.status.branch
        if branch == "-" { return "—" }
        if git.hasLocalChanges {
            return "\(branch) · \(git.status.entries.count)"
        }
        if git.status.ahead > 0 {
            return "\(branch) · ↑\(git.status.ahead)"
        }
        return branch
    }

    @ViewBuilder
    private var menuBarPrimaryDevAction: some View {
        let t = DevServerPhaseVisuals.treatment(phase: devServer.phase, defaultPort: defaultDevPort)
        switch devServer.phase {
        case .preflighting, .starting:
            Button(role: .cancel) {
                devServer.cancelStart()
            } label: {
                Label(t.primaryTitle, systemImage: t.primarySystemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help(t.primaryHelp)
            .accessibilityHint(t.primaryHint)
        case .running:
            Button {
                devServer.stop()
            } label: {
                Label(t.primaryTitle, systemImage: t.primarySystemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help(t.primaryHelp)
            .accessibilityHint(t.primaryHint)
        case .stopping, .restarting:
            Label(t.primaryTitle, systemImage: t.primarySystemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
                .help(t.primaryHelp)
                .accessibilityHint(t.primaryHint)
        case .stopped, .failed:
            Button {
                devServer.start()
            } label: {
                Label(t.primaryTitle, systemImage: t.primarySystemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .disabled(devServer.phase.isTransitional)
            .help(t.primaryHelp)
            .accessibilityHint(t.primaryHint)
        }
    }
}
