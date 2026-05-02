import AppKit
import SwiftUI

/// Sidebar pill showing the current git branch + dirty indicator. Tapping it
/// opens `GitPanel`.
struct GitControl: View {
    @Environment(GitController.self) private var git
    @State private var showPanel = false

    var body: some View {
        Button {
            showPanel = true
        } label: {
            HStack(spacing: 8) {
                statusDot
                Text(statusLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if git.activity != .idle {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else if git.hasLocalChanges {
                    Text("\(git.status.entries.count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.subtextSubtleFill))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.quaternary.opacity(0.35))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(helpText)
        .sheet(isPresented: $showPanel, onDismiss: { git.clearOutcome() }) {
            GitPanel()
        }
        .task {
            // Initial refresh so the pill shows meaningful state.
            git.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextOpenGitPanel)) { _ in
            showPanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .subtextRefreshGit)) { _ in
            git.refresh()
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
    }

    private var statusColor: Color {
        if case .failure = git.outcome { return Color.subtextDanger }
        if git.hasLocalChanges { return Color.subtextWarning }
        if git.status.ahead > 0 { return Color.subtextAccent }
        return .secondary
    }

    private var statusLabel: String {
        if git.status.branch == "-" {
            return "Git"
        }
        if git.hasLocalChanges {
            return "\(git.status.branch) · changes"
        }
        if git.status.ahead > 0 {
            return "\(git.status.branch) · ↑\(git.status.ahead)"
        }
        return git.status.branch
    }

    private var helpText: String {
        if git.hasLocalChanges {
            return "\(git.status.entries.count) changed file(s). Click to commit & push."
        }
        return "Open git commit panel"
    }
}

/// Sheet for staging-everything, writing a commit message, and pushing to
/// origin. Keeps the flow intentionally opinionated: one message, one commit,
/// one push.
struct GitPanel: View {
    @Environment(GitController.self) private var git
    @Environment(CMSStore.self) private var store
    @Environment(PublishController.self) private var publish
    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    @State private var showPublishLog: Bool = false
    @State private var commitFileSelection: Set<String> = []
    @State private var gitDiffPath: String?
    @FocusState private var messageFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(18)

            Divider()

            content
                .padding(18)

            if publish.phase != .idle {
                Divider()
                publishStatusStrip
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }

            Divider()

            footer
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
        .frame(minWidth: 640, minHeight: 560)
        .onAppear {
            git.refresh()
            syncCommitFileSelection()
            messageFocused = true
        }
        .onChange(of: git.status.entries) { _, _ in
            syncCommitFileSelection()
        }
        .sheet(isPresented: $showPublishLog) {
            PublishLogSheet()
        }
    }

    @ViewBuilder
    private var publishStatusStrip: some View {
        HStack(spacing: 10) {
            if publish.isBusy {
                ProgressView().controlSize(.small).scaleEffect(0.8)
            } else if case .failed = publish.phase {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.subtextDanger)
            } else if case .succeeded = publish.phase {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.subtextAccent)
            }

            Text(publish.phase.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer()

            Button {
                showPublishLog = true
            } label: {
                Label("Log", systemImage: "terminal")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(publish.log.isEmpty)

            if !publish.isBusy, publish.phase != .idle {
                Button {
                    publish.reset()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Clear publish status")
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Commit & push")
                    .font(.title3.weight(.semibold))
                branchRow
            }
            Spacer()
            Button {
                git.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .help("Refresh status")
            .accessibilityLabel("Refresh git status")
            .disabled(git.activity == .loading)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([RepoConstants.repoRoot])
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .help("Reveal repo in Finder")
            .accessibilityLabel("Reveal repo in Finder")
        }
    }

    @ViewBuilder
    private var branchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.secondary)
            Text(git.status.branch)
                .font(.callout.weight(.medium).monospaced())
            if let upstream = git.status.upstream {
                Text("→ \(upstream)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text("(no upstream)")
                    .font(.caption)
                    .foregroundStyle(Color.subtextWarning)
            }
            if git.status.ahead > 0 {
                summaryPill("↑\(git.status.ahead)", tint: .subtextAccent)
            }
            if git.status.behind > 0 {
                summaryPill("↓\(git.status.behind)", tint: .subtextWarning)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Changes")
                        .font(.headline)
                    Spacer()
                    if git.status.isClean {
                        Text("Working tree is clean")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(git.status.entries.count) file\(git.status.entries.count == 1 ? "" : "s")")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if !git.status.isClean {
                    stageSelectionToolbar
                }

                fileList
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Message")
                    .font(.headline)
                messageEditor
                if case .success(let text) = git.outcome {
                    statusBanner(text: text, tint: .subtextAccent, systemImage: "checkmark.circle.fill")
                }
                if case .failure(let text) = git.outcome {
                    statusBanner(text: text, tint: .subtextDanger, systemImage: "exclamationmark.triangle.fill")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var fileList: some View {
        Group {
            if git.status.isClean {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(git.status.entries) { entry in
                            HStack(spacing: 8) {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { commitFileSelection.contains(entry.path) },
                                        set: { on in
                                            if on { commitFileSelection.insert(entry.path) }
                                            else { commitFileSelection.remove(entry.path) }
                                        }
                                    )
                                )
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .help("Include in next commit")

                                Text(String(entry.indexCode) + String(entry.worktreeCode))
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(tint(for: entry))
                                    .frame(width: 26, alignment: .leading)

                                Button {
                                    gitDiffPath = entry.path
                                } label: {
                                    Text(entry.path)
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.primary)
                                .help(entry.path)

                                Text(label(for: entry))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(tint(for: entry).opacity(0.10))
                            )
                            .popover(isPresented: Binding(
                                get: { gitDiffPath == entry.path },
                                set: { if !$0 { gitDiffPath = nil } }
                            ), arrowEdge: .trailing) {
                                InlineDiffView(path: entry.path)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.quaternary.opacity(0.22))
                )
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No local changes")
                .font(.callout.weight(.medium))
            Text("Everything is already committed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.quaternary.opacity(0.22))
        )
    }

    @ViewBuilder
    private var messageEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.quaternary.opacity(0.22))
                )
            TextEditor(text: $message)
                .focused($messageFocused)
                .font(.body.monospaced())
                .padding(8)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)

            if message.isEmpty {
                Text("Describe the change in the imperative: \"Update homepage hero\"…")
                    .font(.body.monospaced())
                    .foregroundStyle(.tertiary)
                    .padding(14)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 140)
    }

    @ViewBuilder
    private func statusBanner(text: String, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(text)
                    .font(.caption)
                    .textSelection(.enabled)
                Spacer()
            }
            if text.localizedCaseInsensitiveContains("timed out") {
                Text("Tip: run `git push --verbose` in Terminal to see whether auth, network, or hooks are blocking.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 12) {
            if let stamp = git.lastRefresh {
                Text("Updated \(stamp, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button {
                git.push()
            } label: {
                Label("Push", systemImage: "arrow.up.circle")
            }
            .subtextButton(.secondary)
            .subtextButtonLoading(git.activity == .pushing)
            .disabled(!canPushOnly || git.isBusy)
            .help(pushOnlyHelp)

            Button {
                let text = message
                publish.publish(store: store, git: git, message: text)
            } label: {
                Label(buildAndPublishLabel, systemImage: "hammer")
            }
            .subtextButton(.secondary)
            .subtextButtonLoading(publish.isBusy)
            .disabled(!canPublish || git.isBusy)
            .help("Run `npm run build`, then commit & push if it succeeds (⌘⇧B)")
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Button {
                let text = message
                if git.status.isClean {
                    git.push()
                } else {
                    git.commitAndPush(message: text, stagingPaths: commitStagingPathsOrNil)
                    message = ""
                }
            } label: {
                Label(primaryButtonLabel, systemImage: "arrow.up")
            }
            .subtextButton(.primary)
            .tint(Color.subtextAccent)
            .subtextButtonLoading(git.activity == .committing || git.activity == .pushing)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!canPrimary || git.isBusy)
            .help(primaryHelp)
        }
    }

    private var stageSelectionToolbar: some View {
        HStack(spacing: 12) {
            Text("Staging")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Button("Stage all") {
                commitFileSelection = Set(git.status.entries.map(\.path))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.subtextAccent)
            .disabled(git.status.isClean)
            Button("Stage none") {
                commitFileSelection.removeAll()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(git.status.isClean)
            Spacer()
            if commitFileSelection.isEmpty {
                Text("Select at least one file to commit")
                    .font(.caption2)
                    .foregroundStyle(Color.subtextWarning)
            }
        }
    }

    private func syncCommitFileSelection() {
        let all = Set(git.status.entries.map(\.path))
        if commitFileSelection.isEmpty, !all.isEmpty {
            commitFileSelection = all
            return
        }
        let stillThere = commitFileSelection.intersection(all)
        let added = all.subtracting(commitFileSelection)
        commitFileSelection = stillThere.union(added)
    }

    /// When every file is selected, pass `nil` so the service uses the fast `git add -A` path.
    private var commitStagingPathsOrNil: Set<String>? {
        let all = Set(git.status.entries.map(\.path))
        guard !all.isEmpty, commitFileSelection == all else {
            return commitFileSelection
        }
        return nil
    }

    private var canPublish: Bool {
        guard !publish.isBusy, !git.isBusy else { return false }
        // Need something to publish (local changes or a pending push) AND a message if we'll commit.
        let needsCommit = !git.status.isClean || store.isAnyDirty
        if needsCommit {
            return !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return git.status.ahead > 0 // push-only path: build, then push
    }

    private var buildAndPublishLabel: String {
        switch publish.phase {
        case .saving: return "Saving…"
        case .runningPreBuild: return "Pre-build…"
        case .building: return "Building…"
        case .committing: return "Committing…"
        case .pushing: return "Pushing…"
        case .succeeded: return "Published"
        case .failed: return "Build & Publish"
        case .idle: return "Build & Publish"
        }
    }

    // MARK: - Helpers

    private var canPushOnly: Bool {
        guard !git.isBusy else { return false }
        return git.status.ahead > 0
    }

    private var pushOnlyHelp: String {
        if git.status.ahead > 0 {
            return "Push \(git.status.ahead) local commit(s) to origin"
        }
        return "No local commits waiting to push"
    }

    private var canPrimary: Bool {
        guard !git.isBusy else { return false }
        if git.status.isClean {
            return git.status.ahead > 0 // allow push-only
        }
        let msgOk = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return msgOk && !commitFileSelection.isEmpty
    }

    private var primaryButtonLabel: String {
        switch git.activity {
        case .committing: return "Committing…"
        case .pushing: return "Pushing…"
        case .loading: return "Refreshing…"
        case .syncing: return "Syncing…"
        case .checkingOut: return "Checking out…"
        case .stashing: return "Stashing…"
        case .idle:
            if git.status.isClean {
                return git.status.ahead > 0 ? "Push (\(git.status.ahead))" : "Nothing to do"
            }
            return "Commit & push"
        }
    }

    private var primaryHelp: String {
        if git.status.isClean {
            return git.status.ahead > 0 ? "Push \(git.status.ahead) commit(s) to origin" : "No changes to commit, nothing to push"
        }
        return "Stage selected changes, commit with this message, then push (⌘↩)"
    }

    @ViewBuilder
    private func summaryPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold).monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }

    private func tint(for entry: GitService.Entry) -> Color {
        switch entry.change {
        case .added: return .subtextAccent
        case .modified: return .blue
        case .deleted: return .subtextDanger
        case .renamed, .copied: return .purple
        case .untracked: return .subtextWarning
        case .unmerged: return .subtextDanger
        case .other: return .secondary
        }
    }

    private func label(for entry: GitService.Entry) -> String {
        let base: String
        switch entry.change {
        case .modified: base = "modified"
        case .added: base = "added"
        case .deleted: base = "deleted"
        case .renamed: base = "renamed"
        case .copied: base = "copied"
        case .untracked: base = "untracked"
        case .unmerged: base = "unmerged"
        case .other: base = "changed"
        }
        return entry.isStaged ? "staged · \(base)" : base
    }
}
