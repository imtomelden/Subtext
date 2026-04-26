import AppKit
import SwiftUI

/// Canonical surface for dev server controls, preflight, log, and events.
struct DevServerWindow: View {
    @Environment(DevServerController.self) private var devServer
    @Environment(\.openWindow) private var openWindow
    @State private var logSearch = ""
    @State private var autoScrollLog = true

    private var defaultPort: Int {
        devServer.lastKnownPort ?? RepoConstants.devServerURL.port ?? 4321
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preflightCard
                    logSection
                    eventsSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .onAppear {
            devServer.refreshValidationReportOnly()
        }
    }

    private var header: some View {
        let t = DevServerPhaseVisuals.treatment(phase: devServer.phase, defaultPort: defaultPort)
        return HStack(alignment: .center, spacing: 12) {
            DevServerStatusPill(
                phase: devServer.phase,
                compact: false,
                defaultPort: defaultPort,
                onTap: nil
            )

            Spacer(minLength: 8)

            if devServer.phase.isRunning {
                Button {
                    devServer.restart()
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help(DevServerPhaseVisuals.restartHelp())
                .accessibilityHint(DevServerPhaseVisuals.restartHelp())

                Button {
                    if let url = URL(string: devServer.devServerURLString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open in browser", systemImage: "safari")
                }
                .buttonStyle(.bordered)
                .help(DevServerPhaseVisuals.openInBrowserHelp(port: devServer.phase.displayPort ?? defaultPort))
                .accessibilityHint(DevServerPhaseVisuals.openInBrowserHelp(port: devServer.phase.displayPort ?? defaultPort))
            }

            primaryActionButton(treatment: t)

            Button("Live preview") {
                openWindow(id: "subtext-preview")
            }
            .buttonStyle(.bordered)
            .help(DevServerPhaseVisuals.livePreviewHelp())
        }
        .padding(16)
    }

    @ViewBuilder
    private func primaryActionButton(treatment: DevServerPhaseVisuals.Treatment) -> some View {
        switch devServer.phase {
        case .preflighting, .starting:
            Button(role: .cancel) {
                devServer.cancelStart()
            } label: {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Label(treatment.primaryTitle, systemImage: treatment.primarySystemImage)
                }
            }
            .buttonStyle(.bordered)
            .help(treatment.primaryHelp)
            .accessibilityHint(treatment.primaryHint)
        case .running:
            Button {
                devServer.stop()
            } label: {
                Label(treatment.primaryTitle, systemImage: treatment.primarySystemImage)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .help(treatment.primaryHelp)
            .accessibilityHint(treatment.primaryHint)
        case .stopping, .restarting:
            Button(action: {}) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(treatment.primaryTitle)
                }
            }
            .buttonStyle(.bordered)
            .disabled(true)
            .help(treatment.primaryHelp)
            .accessibilityHint(treatment.primaryHint)
        case .stopped, .failed:
            Button {
                devServer.start()
            } label: {
                Label(treatment.primaryTitle, systemImage: treatment.primarySystemImage)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.subtextAccent)
            .help(treatment.primaryHelp)
            .accessibilityHint(treatment.primaryHint)
        }
    }

    private var preflightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preflight & repair")
                .font(.headline)
            if let msg = devServer.preflightStatusMessage, !msg.isEmpty {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            HStack(spacing: 10) {
                Button {
                    devServer.runPreflight()
                } label: {
                    Label("Run preflight", systemImage: "checklist")
                }
                .buttonStyle(.bordered)
                .disabled(devServer.preflightRunning || devServer.phase.isRunning)
                .help(DevServerPhaseVisuals.runPreflightHelp())
                .accessibilityHint(DevServerPhaseVisuals.runPreflightHelp())

                if devServer.repairableIssueCount > 0 {
                    Button {
                        devServer.repairAndRunPreflight()
                    } label: {
                        Label("Repair content", systemImage: "wrench.adjustable")
                    }
                    .buttonStyle(.bordered)
                    .disabled(devServer.preflightRunning || devServer.phase.isRunning)
                    .help(DevServerPhaseVisuals.repairContentHelp(repairableCount: devServer.repairableIssueCount))
                    .accessibilityHint(DevServerPhaseVisuals.repairContentHelp(repairableCount: devServer.repairableIssueCount))
                }
            }

            if let report = devServer.lastValidationReport, !report.issues.isEmpty {
                Text("Issues")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(report.issues.enumerated()), id: \.offset) { _, issue in
                    Text("\(issue.fileName): \(issue.reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        )
    }

    private var filteredLog: [String] {
        let q = logSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return devServer.log }
        return devServer.log.filter { $0.lowercased().contains(q) }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dev log")
                    .font(.headline)
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScrollLog)
                    .toggleStyle(.checkbox)
                    .help("Scroll to the newest line when new output arrives")
                Button("Clear") { devServer.clearLog() }
                    .disabled(devServer.log.isEmpty)
                    .help("Clear streamed server output")
            }
            TextField("Search log…", text: $logSearch)
                .textFieldStyle(.roundedBorder)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(filteredLog.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 200)
                .background(.quaternary.opacity(0.22))
                .onChange(of: devServer.log.count) { _, newValue in
                    guard autoScrollLog, newValue > 0 else { return }
                    let last = max(filteredLog.count - 1, 0)
                    withAnimation(.linear(duration: 0.08)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent activity")
                    .font(.headline)
                Spacer()
                Button("Clear activity") { devServer.clearEvents() }
                    .disabled(devServer.events.isEmpty)
                    .help("Clear the activity timeline")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(devServer.events.reversed())) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: event.level.iconName)
                                .foregroundStyle(eventColor(event.level))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.message)
                                    .font(.callout)
                                Text(Self.timeFormatter.string(from: event.timestamp))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 120)
            .background(.quaternary.opacity(0.15))
        }
    }

    private func eventColor(_ level: DevServerEvent.Level) -> Color {
        switch level {
        case .info: .secondary
        case .warning: Color.subtextWarning
        case .error: .red
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
