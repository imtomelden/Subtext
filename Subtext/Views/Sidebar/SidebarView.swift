import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarTab
    @Environment(CMSStore.self) private var store
    @Environment(GitController.self) private var git
    @Environment(DevServerController.self) private var devServer
    @Environment(\.openWindow) private var openWindow

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
                .padding(.vertical, 10)

            footerRow
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            GlassSurface(prominence: .regular, cornerRadius: 0) { Color.clear }
                .ignoresSafeArea()
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: SubtextUI.Radius.small, style: .continuous)
                    .fill(Tokens.Accent.subtleFill)
                Image(systemName: "text.append")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.subtextAccent)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("Subtext")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Tokens.Text.primary)
                Text(repoFolderName)
                    .font(.caption2)
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

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 0) {
            gitFooterButton
            devServerFooterButton
            Spacer(minLength: 0)
            folderButton
        }
    }

    private var gitFooterButton: some View {
        Button {
            // Git panel is triggered via keyboard shortcut ⌘⇧K — nothing to do on tap here
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 11, weight: .medium))
                Text(git.status.branch)
                    .font(.caption2)
                    .lineLimit(1)
                if git.status.ahead > 0 || git.status.behind > 0 {
                    gitSyncBadge
                }
            }
            .foregroundStyle(Tokens.Text.tertiary)
            .frame(height: 22)
        }
        .buttonStyle(.plain)
        .help("Git branch — press ⌘⇧K to commit")
    }

    private var devServerFooterButton: some View {
        Button {
            openWindow(id: "subtext-devserver")
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(devServer.phase.isRunning ? Tokens.State.success : Tokens.Text.tertiary)
                    .frame(width: 6, height: 6)
                Image(systemName: "server.rack")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Tokens.Text.tertiary)
            .frame(height: 22)
        }
        .buttonStyle(.plain)
        .padding(.leading, 10)
        .help(devServer.phase.isRunning ? "Dev server running — click to manage" : "Dev server stopped — click to manage")
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

    // MARK: - Git sync badge

    @ViewBuilder
    private var gitSyncBadge: some View {
        let ahead = git.status.ahead
        let behind = git.status.behind
        HStack(spacing: 2) {
            if ahead > 0 {
                Image(systemName: "arrow.up").font(.system(size: 9))
                Text("\(ahead)").font(.caption2.monospacedDigit())
            }
            if behind > 0 {
                Image(systemName: "arrow.down").font(.system(size: 9))
                Text("\(behind)").font(.caption2.monospacedDigit())
            }
        }
        .foregroundStyle(ahead > 0 ? Color.subtextAccent : Color.subtextWarning)
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
            HStack(spacing: 10) {
                // 2pt selection bar on the leading edge
                Rectangle()
                    .fill(isSelected ? Color.subtextAccent : Color.clear)
                    .frame(width: 2)
                    .clipShape(Capsule())
                    .padding(.vertical, 4)

                Image(systemName: tab.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.subtextAccent : Tokens.Text.secondary)

                Text(tab.displayName)
                    .font(isSelected ? .callout.weight(.medium) : .callout)
                    .foregroundStyle(isSelected ? Tokens.Text.primary : Tokens.Text.secondary)
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
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: SubtextUI.Radius.medium, style: .continuous)
                    .fill(
                        isSelected
                            ? Tokens.Accent.subtleFill
                            : (isHovered ? Tokens.Background.elevated : Color.clear)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: SubtextUI.Radius.medium, style: .continuous))
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
            Text("\(dirtyCount)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.subtextAccent))
                .accessibilityLabel("\(dirtyCount) unsaved changes")
        }
    }
}

