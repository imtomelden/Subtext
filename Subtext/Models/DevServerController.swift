import Foundation
import Observation

// MARK: - Phase types (kept in this file so Xcode project Sources stays in sync)

/// Observable dev-server lifecycle phase for UI (sidebar, window, menu bar, preview).
enum DevServerPhase: Equatable, Sendable {
    case stopped
    case preflighting
    case starting
    case running(pid: Int32, port: Int)
    case stopping
    case restarting
    case failed(DevServerFailure)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isTransitional: Bool {
        switch self {
        case .preflighting, .starting, .stopping, .restarting:
            return true
        default:
            return false
        }
    }

    var displayPort: Int? {
        switch self {
        case .running(_, let port):
            return port
        default:
            return nil
        }
    }
}

struct DevServerFailure: Equatable, Sendable {
    var kind: DevServerFailureKind
    var message: String
}

enum DevServerFailureKind: Equatable, Sendable {
    case portConflict
    case alreadyRunning
    case launchFailure
    case schemaValidation
    case preflightFailure
    case unknown

    var label: String {
        switch self {
        case .portConflict: "Port conflict"
        case .alreadyRunning: "Already running"
        case .launchFailure: "Launch failed"
        case .schemaValidation: "Schema validation"
        case .preflightFailure: "Preflight failed"
        case .unknown: "Unknown error"
        }
    }
}

/// Main-actor façade for `BuildService`. Single phase machine; stop waits for the process.
@Observable
@MainActor
final class DevServerController {
    private(set) var phase: DevServerPhase = .stopped
    private(set) var log: [String] = []
    private(set) var events: [DevServerEvent] = []
    private(set) var lastKnownPort: Int?
    private(set) var lastValidationReport: BuildService.PreflightReport?
    private(set) var preflightStatusMessage: String?
    private(set) var preflightRunning = false
    private let maxLogLines: Int = 1000
    private let maxEventLines: Int = 200

    private let service = BuildService()
    private var operationTask: Task<Void, Never>?

    // MARK: - Public actions

    func start() {
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            await self?.runStartSequenceCore()
        }
    }

    func stop() {
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            await self?.runStopSequence()
        }
    }

    func restart() {
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            appendEvent(.info, "Restart requested")
            phase = .restarting
            await runStopSequence()
            phase = .stopped
            await runStartSequenceCore()
        }
    }

    func cancelStart() {
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            await self?.runCancelStartSequence()
        }
    }

    func runPreflight(includeBuild: Bool = false) {
        guard !preflightRunning else { return }
        preflightRunning = true
        Task { [weak self] in
            guard let self else { return }
            defer { preflightRunning = false }
            lastValidationReport = await service.runPreflight(validateOnly: true)
            do {
                let stream = try await service.runHealthCheck(includeBuild: includeBuild)
                var lines: [String] = []
                for await event in stream {
                    switch event {
                    case .line(let line):
                        lines.append(line)
                        append("▸ \(line)")
                    case .finished(let exitCode):
                        if exitCode != 0 {
                            lines.append("Build exited with code \(exitCode)")
                        }
                    }
                }
                let message = lines.isEmpty ? "Preflight passed." : lines.joined(separator: " | ")
                preflightStatusMessage = message
                appendEvent(.info, "Preflight finished")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                preflightStatusMessage = message
                append("⚠︎ \(message)")
                appendEvent(.error, "Preflight failed: \(message)")
            }
        }
    }

    func repairAndRunPreflight() {
        guard !preflightRunning else { return }
        preflightRunning = true
        Task { [weak self] in
            guard let self else { return }
            defer { preflightRunning = false }
            let repaired = await service.applyPreflightRepairs()
            if repaired.isEmpty {
                append("▸ Repair: no changes needed")
            } else {
                append("▸ Repair updated: \(repaired.joined(separator: ", "))")
            }
            let report = await service.runPreflight(validateOnly: true)
            lastValidationReport = report
            do {
                let stream = try await service.runHealthCheck(includeBuild: false)
                var lines: [String] = []
                for await event in stream {
                    switch event {
                    case .line(let line):
                        lines.append(line)
                        append("▸ \(line)")
                    case .finished(let exitCode):
                        if exitCode != 0 {
                            lines.append("Build exited with code \(exitCode)")
                        }
                    }
                }
                preflightStatusMessage = lines.isEmpty ? "Preflight passed." : lines.joined(separator: " | ")
                appendEvent(.info, "Repair and preflight finished")
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                preflightStatusMessage = message
                append("⚠︎ \(message)")
                appendEvent(.error, "Repair/preflight failed: \(message)")
            }
        }
    }

    func refreshValidationReportOnly() {
        Task { [weak self] in
            guard let self else { return }
            let report = await service.runPreflight(validateOnly: true)
            await MainActor.run {
                self.lastValidationReport = report
            }
        }
    }

    func clearLog() {
        log.removeAll()
    }

    func clearEvents() {
        events.removeAll()
    }

    func shutdownForQuit() async {
        operationTask?.cancel()
        await service.shutdownForQuit()
        await service.acknowledgeDevProcessFinished()
        phase = .stopped
    }

    // MARK: - Derived

    var repairableIssueCount: Int {
        lastValidationReport?.repairableChanges.count ?? 0
    }

    var statusSummary: String {
        switch phase {
        case .stopped:
            return "Stopped"
        case .preflighting:
            return "Preflight…"
        case .starting:
            return "Starting…"
        case .running(let pid, let port):
            return "Running · pid \(pid) · port \(port)"
        case .stopping:
            return "Stopping…"
        case .restarting:
            return "Restarting…"
        case .failed(let failure):
            return "\(failure.kind.label) · \(failure.message)"
        }
    }

    var devServerURLString: String {
        let port = phase.displayPort ?? lastKnownPort ?? RepoConstants.devServerURL.port ?? 4321
        return "http://localhost:\(port)/"
    }

    var conflictRecoveryHint: String? {
        guard case .failed(let f) = phase, f.kind == .portConflict else { return nil }
        let port = phase.displayPort ?? lastKnownPort ?? 4321
        return "Another process may be using port \(port). Start reaps matching repo dev servers automatically; if this persists, quit other tools using that port."
    }

    var lastFailureKind: DevServerFailureKind? {
        if case .failed(let f) = phase { return f.kind }
        return nil
    }

    // MARK: - Private

    private func runStartSequenceCore() async {
        switch phase {
        case .running, .preflighting, .starting, .stopping, .restarting:
            append("▸ Start ignored: dev server already active")
            appendEvent(.warning, "Start ignored: dev server already active")
            return
        case .stopped, .failed:
            break
        }

        phase = .preflighting
        appendEvent(.info, "Starting dev server")
        append("▸ Preflight (reap + validate)…")

        do {
            try Task.checkCancellation()
            _ = await service.reapOrphanAstroDevProcesses()
            try Task.checkCancellation()
            try await service.runStartupGate()
            let report = await service.runPreflight(validateOnly: true)
            lastValidationReport = report

            try Task.checkCancellation()
            phase = .starting
            let stream = try await service.spawnDevServerProcess()
            let pid = await service.currentPID() ?? 0
            let fallbackPort = lastKnownPort ?? RepoConstants.devServerURL.port ?? 4321
            lastKnownPort = fallbackPort
            phase = .running(pid: pid, port: fallbackPort)

            append("▸ Started `npm run dev` in \(RepoConstants.repoRoot.lastPathComponent)")
            appendEvent(.info, "Dev server started")

            var structuredLaunchError: StructuredLaunchError?
            for await line in stream {
                try Task.checkCancellation()
                append(line)
                if let parsedPort = parsePortFromRuntimeLine(line) {
                    lastKnownPort = parsedPort
                    if case .running(let p, _) = phase {
                        phase = .running(pid: p, port: parsedPort)
                    }
                }
                if let parsed = parseStructuredLaunchError(line) {
                    structuredLaunchError = parsed
                } else if let enriched = parseAstroSchemaErrorLine(line, existing: structuredLaunchError) {
                    structuredLaunchError = enriched
                }
            }
            await service.acknowledgeDevProcessFinished()

            if phase.isRunning {
                if let structuredLaunchError {
                    let detail = structuredLaunchError.userMessage
                    append("⚠︎ \(detail)")
                    phase = .failed(
                        DevServerFailure(kind: structuredLaunchError.kind, message: detail)
                    )
                    appendEvent(.error, "Dev server failed: \(detail)")
                } else {
                    append("▸ Dev server exited")
                    appendEvent(.warning, "Dev server exited")
                    phase = .stopped
                }
            }
        } catch is CancellationError {
            append("▸ Start cancelled")
            appendEvent(.warning, "Start cancelled")
            await service.stop()
            await service.acknowledgeDevProcessFinished()
            phase = .stopped
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let kind = classifyFailureKind(from: message)
            phase = .failed(DevServerFailure(kind: kind, message: message))
            append("⚠︎ \(message)")
            preflightStatusMessage = message
            appendEvent(.error, "Dev server failed to start: \(message)")
            let report = await service.runPreflight(validateOnly: true)
            lastValidationReport = report
        }
    }

    private func runStopSequence() async {
        switch phase {
        case .running, .starting, .preflighting, .restarting:
            phase = .stopping
            append("▸ Stopping dev server…")
            appendEvent(.info, "Stopping dev server")
            await service.stop()
            await service.acknowledgeDevProcessFinished()
            _ = await service.reapOrphanAstroDevProcesses()
            phase = .stopped
        case .stopping:
            return
        case .failed:
            phase = .stopped
        case .stopped:
            append("▸ Stop ignored: dev server is not running")
            appendEvent(.warning, "Stop ignored: dev server is not running")
        }
    }

    private func runCancelStartSequence() async {
        switch phase {
        case .preflighting, .starting:
            append("▸ Cancelling start…")
            appendEvent(.warning, "Start cancelled")
            await service.stop()
            await service.acknowledgeDevProcessFinished()
            phase = .stopped
        default:
            break
        }
    }

    private func append(_ line: String) {
        log.append(line)
        if log.count > maxLogLines {
            log.removeFirst(log.count - maxLogLines)
        }
    }

    private func appendEvent(_ level: DevServerEvent.Level, _ message: String) {
        events.append(DevServerEvent(level: level, message: message))
        if events.count > maxEventLines {
            events.removeFirst(events.count - maxEventLines)
        }
    }

    private struct StructuredLaunchError {
        var summary: String
        var kind: DevServerFailureKind
        var filePath: String?
        var field: String?

        var userMessage: String {
            var parts: [String] = [summary]
            if let field, !field.isEmpty {
                parts.append("Field: \(field)")
            }
            if let filePath, !filePath.isEmpty {
                parts.append("File: \(filePath)")
            }
            return parts.joined(separator: " • ")
        }
    }

    private func parseStructuredLaunchError(_ line: String) -> StructuredLaunchError? {
        let marker = "⚠︎ [SubtextLaunchError] "
        guard line.hasPrefix(marker) else { return nil }
        let detail = String(line.dropFirst(marker.count))
        return StructuredLaunchError(summary: detail, kind: classifyFailureKind(from: detail), filePath: nil, field: nil)
    }

    private func parseAstroSchemaErrorLine(_ line: String, existing: StructuredLaunchError?) -> StructuredLaunchError? {
        var current = existing

        if line.contains("[InvalidContentEntryDataError]") {
            if current == nil {
                current = StructuredLaunchError(
                    summary: "Dev server failed because project frontmatter does not match Astro schema",
                    kind: .schemaValidation,
                    filePath: nil,
                    field: nil
                )
            }
        }
        if line.contains("Required"), line.contains(":") {
            if let field = extractLikelyFieldName(from: line), current != nil {
                current?.field = field
            }
        }
        if line.contains("/src/content/projects/"), line.contains(".mdx"), current != nil {
            current?.filePath = line.replacingOccurrences(of: "⚠︎ ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return current
    }

    private func extractLikelyFieldName(from line: String) -> String? {
        if line.contains("slug") { return "slug" }
        if line.contains("title") { return "title" }
        if line.contains("description") { return "description" }
        if line.contains("date") { return "date" }
        if line.contains("category") { return "category" }
        return nil
    }

    private func classifyFailureKind(from message: String) -> DevServerFailureKind {
        let lower = message.lowercased()
        if lower.contains("already in use") || (lower.contains("port") && lower.contains("in use")) {
            return .portConflict
        }
        if lower.contains("already running") {
            return .alreadyRunning
        }
        if lower.contains("schema validation") || lower.contains("invalidcontententrydataerror") {
            return .schemaValidation
        }
        if lower.contains("preflight") {
            return .preflightFailure
        }
        if lower.contains("failed to launch") || lower.contains("launch") {
            return .launchFailure
        }
        return .unknown
    }

    private func parsePortFromRuntimeLine(_ line: String) -> Int? {
        guard line.contains("localhost:") || line.contains("127.0.0.1:") || line.contains("Port ") else {
            return nil
        }
        let digits = line.split(whereSeparator: { !$0.isNumber })
        for chunk in digits {
            if let value = Int(chunk), (1024...65535).contains(value) {
                return value
            }
        }
        return nil
    }
}

struct DevServerEvent: Identifiable, Equatable {
    enum Level: String {
        case info
        case warning
        case error

        var iconName: String {
            switch self {
            case .info: "info.circle"
            case .warning: "exclamationmark.triangle"
            case .error: "xmark.octagon"
            }
        }
    }

    let id: UUID = UUID()
    let timestamp: Date = Date()
    let level: Level
    let message: String
}
