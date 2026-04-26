import SwiftUI

struct SiteSettingsView: View {
    @Environment(CMSStore.self) private var store
    @Environment(DevServerController.self) private var devServer
    @Environment(\.openWindow) private var openWindow
    @AppStorage("SubtextContentDensityCompact") private var useCompactDensity = false
    @AppStorage("SubtextAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("SubtextProjectLiveMarkdownPreviewEnabled") private var liveMarkdownEnabled = true
    @State private var showHistory = false
    @State private var showSourcePreview = false
    @State private var showAssetBrowser = false
    @State private var showSiteHealth = false
    @State private var showEventLog = false
    @State private var repoRootPath: String = RepoConstants.repoRoot.path(percentEncoded: false)
    @State private var repoSelectionError: String?

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                Form {
                    Section {
                        Picker("Color appearance", selection: $appearanceModeRaw) {
                            ForEach(AppAppearanceMode.allCases) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle(isOn: $useCompactDensity) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Compact layout")
                                    .font(.body.weight(.medium))
                                Text("Tighter spacing on Home and Projects.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(Color.subtextAccent)

                        Toggle(isOn: $liveMarkdownEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live markdown preview in Projects")
                                    .font(.body.weight(.medium))
                                Text("Shows rendered markdown while editing project body content.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(Color.subtextAccent)
                    } header: {
                        Text("Appearance")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Toggle(isOn: $store.siteSettings.blogPublic) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Blog publicly visible")
                                    .font(.body.weight(.medium))
                                Text("When off, the blog is hidden from imtomelden.com.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(Color.subtextAccent)
                    } header: {
                        Text("Public visibility")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        repoRootField
                        recentReposList
                    } header: {
                        Text("Website repo")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Subtext reads and writes splash.json, site.json, and the projects folder inside this directory. Backups are taken for session changes when you close the app/window; delete and restore actions always force a backup immediately. macOS may show a file-access prompt for folders under Documents/Desktop; choose Allow to let Subtext and the dev server read project files. Use Re-pick folder access if macOS access was revoked. For fewer prompts, keep your website repo outside protected folders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        toolsRow
                    } header: {
                        Text("Site health")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Browse every file under /public/images and audit the site for orphan assets, broken references, and missing SEO fields.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(
                    GlassSurface(prominence: .interactive, cornerRadius: 14) { Color.clear }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
            }
            .padding(.top, 28)
            .padding(.bottom, 80)
        }
        .sheet(isPresented: $showHistory) {
            SiteHistoryPanel()
        }
        .sheet(isPresented: $showSourcePreview) {
            SourcePreviewDrawer(source: .site(store.siteSettings)) {
                showSourcePreview = false
            }
        }
        .sheet(isPresented: $showAssetBrowser) {
            AssetBrowserSheet()
        }
        .sheet(isPresented: $showSiteHealth) {
            SiteHealthSheet()
        }
        .sheet(isPresented: $showEventLog) {
            EventLogSheet()
        }
        .onChange(of: store.presentEventLogToken) { _, token in
            if token != nil {
                showEventLog = true
            }
        }
        .onChange(of: showEventLog) { _, isShowing in
            if !isShowing {
                store.clearPresentEventLogRequest()
            }
        }
        .alert("Folder validation failed", isPresented: Binding(
            get: { repoSelectionError != nil },
            set: { if !$0 { repoSelectionError = nil } }
        ), presenting: repoSelectionError) { _ in
            Button("OK", role: .cancel) { repoSelectionError = nil }
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var recentReposList: some View {
        let currentPath = RepoConstants.repoRoot.path(percentEncoded: false)
        let entries = RecentRepos.resolvedEntries().filter { $0.url.path(percentEncoded: false) != currentPath }

        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent websites")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(entries, id: \.url) { entry in
                    Button {
                        switchToRecentRepo(entry.url)
                    } label: {
                        Label(entry.label, systemImage: "folder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.top, 6)
        }
    }

    private func switchToRecentRepo(_ url: URL) {
        do {
            try RepoValidator.assertValidRepoSelection(at: url)
        } catch {
            repoSelectionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }
        RepoConstants.setRepoRoot(url)
        repoRootPath = RepoConstants.repoRoot.path(percentEncoded: false)
        Task { await store.loadAll() }
    }

    @ViewBuilder
    private var toolsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    showAssetBrowser = true
                } label: {
                    Label("Browse assets…", systemImage: "photo.stack")
                }
                .buttonStyle(.bordered)

                Button {
                    showSiteHealth = true
                } label: {
                    Label("Run site audit…", systemImage: "stethoscope")
                }
                .buttonStyle(.bordered)

                Button {
                    showEventLog = true
                } label: {
                    Label(eventLogLabel, systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)

                Button {
                    openWindow(id: "subtext-devserver")
                } label: {
                    Label("Open Dev Server…", systemImage: "gearshape.2")
                }
                .buttonStyle(.bordered)
                .help(DevServerPhaseVisuals.openDevServerWindowHelp())
                .accessibilityHint(DevServerPhaseVisuals.openDevServerWindowHelp())
            }

            if let message = devServer.preflightStatusMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private var eventLogLabel: String {
        let errors = store.eventLog.errorCount
        guard errors > 0 else { return "Event log…" }
        return "Event log (\(errors) error\(errors == 1 ? "" : "s"))…"
    }

    @ViewBuilder
    private var repoRootField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.subtextAccent)
                Text(repoRootPath)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button {
                    chooseRepoRoot()
                } label: {
                    Label("Re-pick folder access…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([RepoConstants.repoRoot])
                } label: {
                    Label("Reveal", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)

                if !RepoConstants.isUsingDefaultRepoRoot {
                    Button(role: .destructive) {
                        RepoConstants.resetToDefaultRepoRoot()
                        repoRootPath = RepoConstants.repoRoot.path(percentEncoded: false)
                        Task { await store.loadAll() }
                    } label: {
                        Label("Reset", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func chooseRepoRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = RepoConstants.repoRoot.deletingLastPathComponent()
        panel.prompt = "Use folder"
        panel.message = "Pick the Astro website repo containing src/content."

        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        do {
            try RepoValidator.assertValidRepoSelection(at: chosen)
        } catch {
            repoSelectionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }
        RepoConstants.setRepoRoot(chosen)
        repoRootPath = RepoConstants.repoRoot.path(percentEncoded: false)
        Task { await store.loadAll() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))
                Text("Top-level site flags. Stored in site.json.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 10) {
                RevealInFinderButton(
                    url: RepoConstants.siteFile,
                    helpText: "Reveal site.json in Finder"
                )

                Button {
                    showSourcePreview = true
                } label: {
                    Image(systemName: "curlybraces")
                }
                .help("Preview site.json source")
                .accessibilityLabel("Preview source")
                .buttonStyle(.bordered)

                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .help("Version history for site.json")
                .accessibilityLabel("Version history")
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 28)
    }
}

struct SiteHistoryPanel: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [BackupService.BackupEntry] = []
    @State private var loading = true
    @State private var diffTarget: BackupService.BackupEntry?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("site.json history").font(.title3.weight(.semibold))
                    Text("\(entries.count) backup\(entries.count == 1 ? "" : "s") retained")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                Text("No backups yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            HistoryRow(entry: entry) {
                                diffTarget = entry
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 520, height: 420)
        .task { await refresh() }
        .sheet(item: $diffTarget) { entry in
            HistoryDiffSheet(
                title: "site.json — backup vs current",
                backup: entry,
                liveFile: RepoConstants.siteFile
            ) {
                await store.restoreSite(from: entry.url)
                await refresh()
                dismiss()
            }
        }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        entries = (try? await store.backupService.listBackups(for: "site.json")) ?? []
    }
}
