import SwiftUI

/// Collapsible inline dashboard mounted at the bottom of the sidebar.
///
/// Sections:
///  - **Git** — branch pill + branch switcher popover, ahead/behind counts,
///    sync button (fetch + fast-forward pull), dirty file list with per-file
///    diff popover, one-click commit & push shortcut.
///  - **Dev server** — status pill, start/stop, compact log tail.
struct DevDashboardPanel: View {
    @Environment(GitController.self) private var git
    @Environment(DevServerController.self) private var devServer
    @Environment(\.openWindow) private var openWindow

    @State private var showBranchSwitcher = false
    @State private var diffTarget: String? = nil
    @State private var showGitPanel = false
    @State private var logExpanded = false
    @State private var showFullDevServerLog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            gitSection
            Divider().padding(.vertical, 4)
            devServerSection
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .sheet(isPresented: $showGitPanel, onDismiss: { git.clearOutcome() }) {
            GitPanel()
        }
        .sheet(isPresented: $showFullDevServerLog) {
            fullDevServerLogSheet
        }
    }

    // MARK: - Git

    private var gitSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Branch row
            HStack(spacing: 6) {
                Button {
                    showBranchSwitcher = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10, weight: .semibold))
                        Text(git.status.branch)
                            .font(.caption.weight(.medium).monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(Tokens.Text.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.subtextSubtleFill)
                    )
                }
                .buttonStyle(.plain)
                .help("Switch branch")
                .popover(isPresented: $showBranchSwitcher, arrowEdge: .bottom) {
                    BranchSwitcher()
                }

                Spacer()

                syncBadges
                syncButton
            }

            gitStashToolbar

            // Dirty files
            if !git.status.isClean {
                dirtyFilesList
            } else if git.status.isClean && git.status.ahead == 0 {
                Label("Working tree clean", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Outcome banner
            if case .success(let msg) = git.outcome {
                outcomeBanner(msg, tint: .subtextAccent, icon: "checkmark.circle.fill")
            } else if case .failure(let msg) = git.outcome {
                outcomeBanner(msg, tint: .subtextDanger, icon: "exclamationmark.triangle.fill")
                    .onTapGesture { git.clearOutcome() }
            }
        }
    }

    @ViewBuilder
    private var syncBadges: some View {
        if git.status.ahead > 0 || git.status.behind > 0 {
            HStack(spacing: 3) {
                if git.status.ahead > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up").font(.caption2)
                        NumberRoll(value: git.status.ahead,
                                   font: .caption2.monospacedDigit(),
                                   color: Color.subtextAccent)
                    }
                    .foregroundStyle(Color.subtextAccent)
                }
                if git.status.behind > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down").font(.caption2)
                        NumberRoll(value: git.status.behind,
                                   font: .caption2.monospacedDigit(),
                                   color: Color.subtextWarning)
                    }
                    .foregroundStyle(Color.subtextWarning)
                }
            }
        }
    }

    private var syncButton: some View {
        Button {
            git.sync()
        } label: {
            Group {
                if git.activity == .syncing {
                    ProgressView().controlSize(.small).scaleEffect(0.75)
                } else {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.Text.secondary)
        .help("Fetch + pull (fast-forward)")
        .disabled(git.isBusy)
    }

    @ViewBuilder
    private var gitStashToolbar: some View {
        if !git.status.isClean || git.hasStash {
            HStack(spacing: 8) {
                if !git.status.isClean {
                    Button {
                        git.stashChanges()
                    } label: {
                        Text("Stash")
                            .font(.caption2.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tokens.Text.secondary)
                    .disabled(git.isBusy)
                    .help("Stash uncommitted changes including untracked")
                }
                if git.hasStash {
                    Button {
                        git.stashPop()
                    } label: {
                        Text("Pop stash")
                            .font(.caption2.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.subtextAccent)
                    .disabled(git.isBusy)
                    .help("Apply and remove the newest stash")
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var dirtyFilesList: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(git.status.entries.count) change\(git.status.entries.count == 1 ? "" : "s")")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showGitPanel = true
                } label: {
                    Label("Commit…", systemImage: "arrow.up.circle")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.subtextAccent)
                .help("Open commit panel")
            }

            ForEach(git.status.entries.prefix(8)) { entry in
                Button {
                    diffTarget = entry.path
                } label: {
                    HStack(spacing: 5) {
                        Text(String(entry.indexCode) + String(entry.worktreeCode))
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            .foregroundStyle(entryTint(entry))
                            .frame(width: 18, alignment: .leading)
                        Text(URL(fileURLWithPath: entry.path).lastPathComponent)
                            .font(.caption2.monospaced())
                            .foregroundStyle(Tokens.Text.primary)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: Binding(
                    get: { diffTarget == entry.path },
                    set: { if !$0 { diffTarget = nil } }
                ), arrowEdge: .trailing) {
                    InlineDiffView(path: entry.path)
                }
                .help("View diff for \(entry.path)")
            }

            if git.status.entries.count > 8 {
                Text("+ \(git.status.entries.count - 8) more — open commit panel")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.22))
        )
    }

    @ViewBuilder
    private func outcomeBanner(_ text: String, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption2)
                .foregroundStyle(Tokens.Text.secondary)
                .lineLimit(3)
            Spacer()
            Button { git.clearOutcome() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    // MARK: - Dev server

    private var devServerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(serverStatusColor)
                    .frame(width: 7, height: 7)
                    .animation(Motion.snappy, value: devServer.phase.isRunning)

                Text(serverPhaseLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Tokens.Text.secondary)
                    .lineLimit(1)

                Spacer()

                serverActionButtons
            }

            // Compact log tail — last 3 lines
            if !devServer.log.isEmpty {
                Button {
                    withAnimation(Motion.spring) { logExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: logExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text("Log")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if logExpanded {
                    logTail
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                }

                Button {
                    showFullDevServerLog = true
                } label: {
                    Text("View full log")
                        .font(.caption2.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.subtextAccent)
                .padding(.top, 2)
            }
        }
    }

    private var fullDevServerLogSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Dev server log")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { showFullDevServerLog = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            ScrollView {
                Text(devServer.log.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(minWidth: 520, minHeight: 440)
    }

    @ViewBuilder
    private var serverActionButtons: some View {
        HStack(spacing: 4) {
            if devServer.phase.isRunning {
                Button {
                    devServer.stop()
                } label: {
                    Text("Stop")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.subtextDanger)

                Button {
                    if let url = URL(string: devServer.devServerURLString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.Text.tertiary)
                .help("Open in browser")
            } else if !devServer.phase.isRunning && !devServer.phase.isTransitional {
                Button {
                    devServer.start()
                } label: {
                    Text("Start")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.subtextAccent)
            } else {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            }

            Button {
                openWindow(id: "subtext-devserver")
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Tokens.Text.tertiary)
            .help("Open dev server window")
            .opacity(devServer.phase.isRunning ? 0 : 1)  // hidden when open button already shown
        }
    }

    private var logTail: some View {
        let lines = devServer.log.suffix(5)
        return VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.quaternary.opacity(0.22))
        )
    }

    // MARK: - Helpers

    private var serverStatusColor: Color {
        switch devServer.phase {
        case .running: Tokens.State.success
        case .failed: Color.subtextDanger
        case .starting, .preflighting, .restarting: Color.subtextWarning
        case .stopping, .stopped: Tokens.Text.tertiary
        }
    }

    private var serverPhaseLabel: String {
        switch devServer.phase {
        case .stopped: "Stopped"
        case .preflighting: "Preflighting…"
        case .starting: "Starting…"
        case .running: "Running"
        case .stopping: "Stopping…"
        case .restarting: "Restarting…"
        case .failed: "Failed"
        }
    }

    private func entryTint(_ entry: GitService.Entry) -> Color {
        switch entry.change {
        case .added: Color.subtextAccent
        case .modified: .blue
        case .deleted: Color.subtextDanger
        case .renamed, .copied: .purple
        case .untracked: Color.subtextWarning
        case .unmerged: Color.subtextDanger
        case .other: .secondary
        }
    }
}
