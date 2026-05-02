import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarTab
    @Environment(CMSStore.self) private var store
    @Environment(GitController.self) private var git
    @Environment(DevServerController.self) private var devServer
    @Environment(\.openWindow) private var openWindow

    @State private var dashboardExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.top, 28)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            navSection

            Spacer()

            Divider()
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)

            // Git & Server dashboard toggle
            dashboardToggleRow
                .padding(.horizontal, 10)

            if dashboardExpanded {
                DevDashboardPanel()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }

            Divider()
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

            footerRow
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tokens.Fill.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Tokens.Border.sidebar)
                .frame(width: 1)
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.subtextAccent.opacity(0.10))
                Text("S")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.subtextAccent)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("Subtext")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Tokens.Text.primary)
                    .tracking(-0.2)
                Text(repoFolderName)
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var repoFolderName: String {
        RepoConstants.repoRoot.lastPathComponent
    }

    // MARK: - Navigation

    private var navSection: some View {
        VStack(spacing: 2) {
            ForEach(SidebarTab.allCases) { tab in
                SidebarRow(
                    tab: tab,
                    isSelected: selection == tab,
                    dirtyCount: store.dirtyCount(for: tab),
                    hasHealthIssues: tab == .settings && store.siteHealthOpenIssueTotal > 0
                ) {
                    selection = tab
                }
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Dashboard toggle

    private var dashboardToggleRow: some View {
        Button {
            withAnimation(Motion.spring) { dashboardExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: dashboardExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(gitIndicatorColor)

                Text(git.status.branch == "-" ? "Git & Server" : git.status.branch)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Tokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Dirty dot
                if git.hasLocalChanges {
                    Circle()
                        .fill(Color.subtextWarning)
                        .frame(width: 6, height: 6)
                }

                // Server dot
                Circle()
                    .fill(devServer.phase.isRunning ? Tokens.State.success : Tokens.Text.tertiary)
                    .frame(width: 6, height: 6)
                    .animation(Motion.snappy, value: devServer.phase.isRunning)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(dashboardExpanded ? "Collapse git & server panel" : "Expand git & server panel")
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 6) {
            // Green dot: lit when dev server running, grey otherwise
            Circle()
                .fill(devServer.phase.isRunning ? Color(red: 0.13, green: 0.77, blue: 0.37) : Tokens.Text.tertiary)
                .frame(width: 7, height: 7)
                .animation(Motion.snappy, value: devServer.phase.isRunning)

            Text(git.status.branch)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Tokens.Text.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if git.status.ahead > 0 || git.status.behind > 0 {
                gitSyncBadge
            }

            folderButton
        }
    }

    private var folderButton: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([RepoConstants.repoRoot])
        } label: {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.Text.tertiary)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help("Reveal website repo in Finder")
    }

    private var gitIndicatorColor: Color {
        if case .failure = git.outcome { return Color.subtextDanger }
        if git.hasLocalChanges { return Color.subtextWarning }
        if git.status.ahead > 0 { return Color.subtextAccent }
        return Tokens.Text.tertiary
    }

    // MARK: - Git sync badge

    @ViewBuilder
    private var gitSyncBadge: some View {
        let ahead = git.status.ahead
        let behind = git.status.behind
        HStack(spacing: 2) {
            if ahead > 0 {
                Text("↑\(ahead)").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.subtextAccent)
            }
            if behind > 0 {
                Text("↓\(behind)").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.subtextWarning)
            }
        }
        .foregroundStyle(Tokens.Text.tertiary)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let tab: SidebarTab
    let isSelected: Bool
    let dirtyCount: Int
    let hasHealthIssues: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                // 2×15pt selection bar on the leading edge
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? Color.subtextAccent : Color.clear)
                    .frame(width: 2, height: 15)

                Text(tab.displayName)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Tokens.Text.primary : Tokens.Text.secondary)
                    .tracking(-0.12)
                    .lineLimit(1)

                Spacer()

                if hasHealthIssues {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.subtextWarning)
                        .help("Site audit reported open issues")
                }

                dirtyBadge
            }
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.subtextAccent.opacity(0.10) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var dirtyBadge: some View {
        switch dirtyCount {
        case 0:
            EmptyView()
        case 1:
            Circle()
                .fill(Color.subtextAccent)
                .frame(width: 7, height: 7)
                .accessibilityLabel("1 unsaved change")
        default:
            NumberRoll(value: dirtyCount, font: .caption2.weight(.bold).monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.subtextAccent))
                .accessibilityLabel("\(dirtyCount) unsaved changes")
        }
    }
}

