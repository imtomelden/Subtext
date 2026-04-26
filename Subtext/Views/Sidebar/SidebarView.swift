import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarTab
    @Environment(CMSStore.self) private var store
    @Environment(GitController.self) private var git
    @State private var hoveredTab: SidebarTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.top, 40)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            List(selection: $selection) {
                ForEach(SidebarTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        rowContent(for: tab)
                    }
                    .onHover { isHovering in
                        hoveredTab = isHovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer()

            statusFooter
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            GlassSurface(prominence: .regular, cornerRadius: 0) { Color.clear }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var brandHeader: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.subtextAccent.opacity(0.14))
                Image(systemName: "text.append")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.subtextAccent)
            }
            .frame(width: 26, height: 26)

            Text("Subtext")
                .font(SubtextUI.Typography.bodyStrong)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func rowContent(for tab: SidebarTab) -> some View {
        let isActive = tab == selection
        let isHovered = hoveredTab == tab

        HStack(spacing: 10) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 18)
                .foregroundStyle(isActive ? Color.subtextAccent : .secondary)
            Text(tab.displayName)
                .font(isActive ? SubtextUI.Typography.bodyStrong : SubtextUI.Typography.body)
                .lineLimit(1)
            Spacer()
            if tab == .settings, store.siteHealthOpenIssueTotal > 0 {
                Image(systemName: "stethoscope")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.subtextWarning)
                    .accessibilityLabel("Site audit reported \(store.siteHealthOpenIssueTotal) open issues")
                    .help("Run a site audit from Settings — open issues from the last scan")
            }
            dirtyBadge(count: store.dirtyCount(for: tab))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isActive
                        ? Color.subtextAccent.opacity(0.13)
                        : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
        )
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Color.subtextAccent)
                .frame(width: 3, height: 14)
                .opacity(isActive ? 1 : 0)
                .padding(.leading, 4)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Compact unsaved-count indicator. 0 hides the badge; 1 shows a dot;
    /// higher counts show the number so Projects with multiple dirty files
    /// doesn't look the same as a single edit elsewhere.
    @ViewBuilder
    private func dirtyBadge(count: Int) -> some View {
        switch count {
        case 0:
            EmptyView()
        case 1:
            Circle()
                .fill(Color.subtextAccent)
                .frame(width: 7, height: 7)
                .accessibilityLabel("1 unsaved change")
        default:
            Text("\(count)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.subtextAccent))
                .accessibilityLabel("\(count) unsaved changes")
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            GitControl()
            DevServerControl()

            HStack(spacing: 6) {
                Text(repoPath)
                    .font(SubtextUI.Typography.captionMuted.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                gitSyncBadge

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([RepoConstants.repoRoot])
                } label: {
                    Image(systemName: "folder")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .help("Reveal website repo in Finder")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var repoPath: String {
        RepoConstants.repoRoot.path(percentEncoded: false)
    }

    /// Tiny git ahead/behind indicator — hidden when both are zero and no
    /// upstream is set, to avoid distracting during a first-time setup.
    @ViewBuilder
    private var gitSyncBadge: some View {
        let ahead = git.status.ahead
        let behind = git.status.behind
        if ahead > 0 || behind > 0 {
            HStack(spacing: 2) {
                if ahead > 0 {
                    Image(systemName: "arrow.up").font(.caption2)
                    Text("\(ahead)").font(.caption2.monospacedDigit())
                }
                if behind > 0 {
                    Image(systemName: "arrow.down").font(.caption2)
                    Text("\(behind)").font(.caption2.monospacedDigit())
                }
            }
            .foregroundStyle(ahead > 0 ? Color.subtextAccent : Color.subtextWarning)
            .help(gitSyncHelp(ahead: ahead, behind: behind))
        } else {
            EmptyView()
        }
    }

    private func gitSyncHelp(ahead: Int, behind: Int) -> String {
        switch (ahead, behind) {
        case (let a, 0) where a > 0: "\(a) commit\(a == 1 ? "" : "s") to push"
        case (0, let b) where b > 0: "\(b) commit\(b == 1 ? "" : "s") to pull"
        default: "\(ahead) ahead, \(behind) behind"
        }
    }
}
