import SwiftUI

struct SiteSettingsView: View {
    @Environment(CMSStore.self) private var store
    @Environment(DevServerController.self) private var devServer
    @Environment(Theme.self) private var theme
    @Environment(\.openWindow) private var openWindow
    @AppStorage("SubtextContentDensityCompact") private var useCompactDensity = false
    @AppStorage("SubtextAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @State private var activeModal: ActiveModal?
    @State private var repoRootPath: String = RepoConstants.repoRoot.path(percentEncoded: false)
    @State private var repoSelectionError: String?

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    accentBackgroundGroup
                    appearanceGroup
                    visibilityGroup
                    websiteRepoGroup
                    siteHealthGroup
                    telemetryGroup
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 28)
            .padding(.bottom, 80)
        }
        .sheet(item: $activeModal) { modal in
            switch modal {
            case .history:
                SiteHistoryPanel()
            case .sourcePreview:
                SourcePreviewDrawer(source: .site(store.siteSettings)) {
                    activeModal = nil
                }
            case .assetBrowser:
                AssetBrowserSheet()
            case .siteHealth:
                SiteHealthSheet()
            case .eventLog:
                EventLogSheet()
            case .performanceBaseline:
                PerformanceBaselineSheet()
            }
        }
        .onChange(of: store.presentEventLogToken) { _, token in
            if token != nil { activeModal = .eventLog }
        }
        .onChange(of: activeModal) { _, modal in
            if modal != .eventLog { store.clearPresentEventLogRequest() }
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

    // MARK: - Groups

    @ViewBuilder
    private var accentBackgroundGroup: some View {
        @Bindable var store = store
        SettingsGroup(title: "ACCENT & BACKGROUND") {
            SettingsRow(label: "Accent colour") {
                HStack(spacing: 10) {
                    ForEach(Theme.AccentPreset.allCases) { preset in
                        Button {
                            withAnimation(Motion.snappy) { theme.setAccent(preset) }
                        } label: {
                            let active = theme.accentPreset == preset
                            Circle()
                                .fill(preset.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: active ? 2 : 0)
                                        .padding(1)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(active ? preset.color.opacity(0.5) : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Accent: \(preset.label)")
                        .accessibilityAddTraits(theme.accentPreset == preset ? .isSelected : [])
                    }
                }
            }

            SettingsRow(label: "Ambient background") {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(Theme.AmbientStyle.allCases) { style in
                        ambientStyleTile(style)
                    }
                }
            }

            SettingsRow(label: "Pre-build command", hint: "Runs before build. Non-zero exit aborts the pipeline.", isLast: true) {
                TextField(
                    "e.g. npx prettier --check \"src/**/*.mdx\"",
                    text: preBuildScriptBinding(for: store),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Tokens.Background.sunken)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Tokens.Border.default, lineWidth: 1)
                        )
                )
                .frame(maxWidth: 340)
            }
        }
    }

    @ViewBuilder
    private var appearanceGroup: some View {
        SettingsGroup(title: "APPEARANCE") {
            SettingsRow(label: "Color appearance") {
                Picker("", selection: $appearanceModeRaw) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            SettingsRow(label: "Compact layout", hint: "Tighter spacing on Home and Projects.", isLast: true) {
                Toggle("", isOn: $useCompactDensity)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color.subtextAccent)
            }
        }
    }

    @ViewBuilder
    private var visibilityGroup: some View {
        @Bindable var store = store
        SettingsGroup(title: "PUBLIC VISIBILITY") {
            SettingsRow(label: "Blog publicly visible", hint: "When off, the blog is hidden from imtomelden.com.", isLast: true) {
                Toggle("", isOn: $store.siteSettings.blogPublic)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color.subtextAccent)
            }
        }
    }

    @ViewBuilder
    private var websiteRepoGroup: some View {
        SettingsGroup(title: "WEBSITE REPO") {
            repoRootField
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
            if !recentReposEntries.isEmpty {
                Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
                recentReposList
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else {
                Color.clear.frame(height: 8)
            }
        }
    }

    @ViewBuilder
    private var siteHealthGroup: some View {
        SettingsGroup(title: "SITE HEALTH") {
            toolsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var telemetryGroup: some View {
        SettingsGroup(title: "PIPELINE TELEMETRY") {
            pipelineTelemetryPanel
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Tokens.Text.primary)
                    .tracking(-0.78)
                Text("Top-level site flags. Stored in site.json.")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            Spacer()
            HStack(spacing: 6) {
                RevealInFinderButton(
                    url: RepoConstants.siteFile,
                    helpText: "Reveal site.json in Finder"
                )

                Button {
                    activeModal = .sourcePreview
                } label: {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Preview site.json source")

                Button {
                    activeModal = .history
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Version history for site.json")
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Ambient tile

    private func ambientStyleTile(_ style: Theme.AmbientStyle) -> some View {
        let selected = theme.ambient == style
        return Button {
            withAnimation(Motion.snappy) { theme.setAmbient(style) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Tokens.Background.sunken)
                if style == .none {
                    Text("None")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Tokens.Text.tertiary)
                } else {
                    AmbientBackground(style: style)
                        .opacity(0.55)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? Color.subtextAccent : Tokens.Border.subtle, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Pre-build binding

    private func preBuildScriptBinding(for store: CMSStore) -> Binding<String> {
        Binding(
            get: { store.siteSettings.preBuildScript ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                store.siteSettings.preBuildScript = trimmed.isEmpty ? nil : $0
            }
        )
    }

    // MARK: - Repo fields

    private var recentReposEntries: [(bookmark: Data, url: URL, label: String)] {
        let currentPath = RepoConstants.repoRoot.path(percentEncoded: false)
        return RecentRepos.resolvedEntries().filter { $0.url.path(percentEncoded: false) != currentPath }
    }

    @ViewBuilder
    private var recentReposList: some View {
        let entries = recentReposEntries
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent websites")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .padding(.top, 8)
                ForEach(entries, id: \.url) { entry in
                    Button {
                        switchToRecentRepo(entry.url)
                    } label: {
                        Label(entry.label, systemImage: "folder")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Switch website folder to \(entry.label)")
                }
            }
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
    private var repoRootField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.subtextAccent)
                    .font(.system(size: 12))
                Text(repoRootPath)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Tokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current website repository path")
            .accessibilityValue(repoRootPath)

            HStack(spacing: 8) {
                Button {
                    chooseRepoRoot()
                } label: {
                    Label("Re-pick folder access…", systemImage: "folder.badge.plus")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([RepoConstants.repoRoot])
                } label: {
                    Label("Reveal", systemImage: "arrow.up.right.square")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)

                if !RepoConstants.isUsingDefaultRepoRoot {
                    Button(role: .destructive) {
                        RepoConstants.resetToDefaultRepoRoot()
                        repoRootPath = RepoConstants.repoRoot.path(percentEncoded: false)
                        Task { await store.loadAll() }
                    } label: {
                        Label("Reset", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 11.5))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
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

    // MARK: - Site health tools

    @ViewBuilder
    private var toolsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { activeModal = .assetBrowser } label: {
                    Label("Browse assets…", systemImage: "photo.stack").font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)

                Button { activeModal = .siteHealth } label: {
                    Label("Run site audit…", systemImage: "stethoscope").font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)

                Button { activeModal = .eventLog } label: {
                    Label(eventLogLabel, systemImage: "list.bullet.rectangle").font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)

                Button { activeModal = .performanceBaseline } label: {
                    Label("Performance baseline…", systemImage: "gauge.with.dots.needle.67percent").font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)

                Button { openWindow(id: "subtext-devserver") } label: {
                    Label("Open Dev Server…", systemImage: "gearshape.2").font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)
                .help(DevServerPhaseVisuals.openDevServerWindowHelp())
            }
            if let message = devServer.preflightStatusMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(3)
            }
        }
    }

    private var eventLogLabel: String {
        let errors = store.eventLog.errorCount
        guard errors > 0 else { return "Event log…" }
        return "Event log (\(errors) error\(errors == 1 ? "" : "s"))…"
    }

    // MARK: - Telemetry panel

    @ViewBuilder
    private var pipelineTelemetryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Reload")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Text.tertiary)
                telemetryPill("Req", value: store.pipelineTelemetry.reloadRequests)
                telemetryPill("Sup", value: store.pipelineTelemetry.reloadSuperseded)
                telemetryPill("Err", value: store.pipelineTelemetry.reloadFailures)
                Spacer()
                Text(reloadStateLabel)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reload pipeline telemetry")
            .accessibilityValue(
                "Requests \(store.pipelineTelemetry.reloadRequests), superseded \(store.pipelineTelemetry.reloadSuperseded), failures \(store.pipelineTelemetry.reloadFailures), \(reloadStateLabel)"
            )

            HStack(spacing: 12) {
                Text("Save")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Text.tertiary)
                telemetryPill("Req", value: store.pipelineTelemetry.saveRequests)
                telemetryPill("Sup", value: store.pipelineTelemetry.saveSuperseded)
                telemetryPill("Err", value: store.pipelineTelemetry.saveFailures)
                Spacer()
                Text(saveStateLabel)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Save pipeline telemetry")
            .accessibilityValue(
                "Requests \(store.pipelineTelemetry.saveRequests), superseded \(store.pipelineTelemetry.saveSuperseded), failures \(store.pipelineTelemetry.saveFailures), \(saveStateLabel)"
            )
        }
    }

    @ViewBuilder
    private func telemetryPill(_ label: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Tokens.Text.tertiary)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(Tokens.Text.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Tokens.Fill.tag, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(telemetryPillLabel(label))
        .accessibilityValue("\(value)")
    }

    private func telemetryPillLabel(_ label: String) -> String {
        switch label {
        case "Req": return "Requests"
        case "Sup": return "Superseded"
        case "Err": return "Failures"
        default: return label
        }
    }

    private var reloadStateLabel: String {
        switch store.projectReloadPipelineState {
        case .idle: return "State: idle"
        case .running(let total): return "State: running (\(total))"
        case .partial(let completed, let total): return "State: partial (\(completed)/\(total))"
        case .complete(let total): return "State: complete (\(total))"
        case .error(let message): return "State: error (\(message))"
        }
    }

    private var saveStateLabel: String {
        switch store.savePipelineState {
        case .idle: return "State: idle"
        case .running(let target): return "State: running (\(target))"
        case .complete(let target): return "State: complete (\(target))"
        case .error(let target, let message): return "State: error (\(target): \(message))"
        }
    }

    // MARK: - Modal enum

    private enum ActiveModal: String, Identifiable {
        case history, sourcePreview, assetBrowser, siteHealth, eventLog, performanceBaseline
        var id: String { rawValue }
    }
}

// MARK: - SettingsGroup

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Tokens.Text.tertiary)
                .tracking(0.76)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Fill.metaCard)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Tokens.Border.metaCard, lineWidth: 1)
            )
        }
    }
}

// MARK: - SettingsRow

private struct SettingsRow<Control: View>: View {
    let label: String
    var hint: String? = nil
    var isLast: Bool = false
    @ViewBuilder let control: () -> Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Tokens.Text.primary)
                    if let hint {
                        Text(hint)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Tokens.Text.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                control()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Rectangle().fill(Tokens.Border.subtle).frame(height: 1)
            }
        }
    }
}

// MARK: - SiteHistoryPanel

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
