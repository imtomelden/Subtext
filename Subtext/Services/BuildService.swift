import Foundation
import Darwin

/// Environment for `Process` launches from the GUI — inherits the app env and
/// ensures common tool locations are on `PATH` (mirrors `runBuild`).
private func subprocessEnvironment() -> [String: String] {
    var env = ProcessInfo.processInfo.environment
    let defaultPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    if let existing = env["PATH"], !existing.isEmpty {
        env["PATH"] = existing + ":" + defaultPaths
    } else {
        env["PATH"] = defaultPaths
    }
    return env
}

/// When the child can fill the default pipe buffer (~64 KiB) before it exits, it blocks on
/// a write and the parent blocks in `waitUntilExit` — a deadlock. `ps -ax` on a busy
/// machine can exceed that, which deadlocks the reap + preflight path. Drain both pipes
/// in parallel with `waitUntilExit()`.
private func readPipesToEndAndWait(
    outPipe: Pipe,
    errPipe: Pipe,
    _ proc: Process
) -> (out: String, err: String) {
    var stdout = Data()
    var stderr = Data()
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        stdout = outPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
    }
    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        stderr = errPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
    }
    proc.waitUntilExit()
    group.wait()
    return (String(decoding: stdout, as: UTF8.self), String(decoding: stderr, as: UTF8.self))
}

/// Phase 3 stub — shells out to `npm run dev` inside the website repo and
/// streams stdout/stderr back to the caller line-by-line.
actor BuildService {
    struct PreflightIssue: Sendable {
        let fileName: String
        let reason: String
    }

    struct PreflightReport: Sendable {
        let issues: [PreflightIssue]
        let repairableChanges: [String]
        let repoWarnings: [String]

        var isHealthy: Bool { issues.isEmpty && repairableChanges.isEmpty }
    }

    private var process: Process?

    struct StopAllResult: Sendable {
        let matchedPIDs: [Int32]
        let gracefulStops: Int
        let forcedStops: Int
        let failures: [String]

        var totalStopped: Int { gracefulStops + forcedStops }
    }

    enum State: Equatable, Sendable {
        case stopped
        case running(pid: Int32)
    }

    private(set) var state: State = .stopped

    func currentPID() -> Int32? {
        if case .running(let pid) = state { return pid }
        return nil
    }

    enum BuildError: LocalizedError {
        case alreadyRunning
        case launchFailed(String)
        case preflightFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRunning: "Dev server is already running."
            case .launchFailed(let reason): "Failed to launch dev server: \(reason)"
            case .preflightFailed(let reason): "Dev server preflight failed: \(reason)"
            }
        }
    }

    /// Clears dev-server process state after its output stream ends (natural
    /// exit, crash, or external kill). Keeps `state` aligned with `stop()`.
    func acknowledgeDevProcessFinished() {
        process = nil
        state = .stopped
    }

    /// Reaps repo-scoped `astro dev` processes (including ones started outside Subtext).
    @discardableResult
    func reapOrphanAstroDevProcesses() -> StopAllResult {
        stopAllAstroForCurrentRepo()
    }

    /// Health-check script + content preflight (same gate as `startDev` before spawn).
    func runStartupGate() throws {
        do {
            try runHealthCheckScript()
        } catch {
            throw BuildError.preflightFailed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
        let report = runPreflight(validateOnly: true)
        if !report.isHealthy {
            var details: [String] = []
            if !report.issues.isEmpty {
                let summary = report.issues
                    .prefix(4)
                    .map { "\($0.fileName): \($0.reason)" }
                    .joined(separator: " | ")
                details.append(summary)
            }
            if !report.repairableChanges.isEmpty {
                details.append("repair required: \(report.repairableChanges.prefix(3).joined(separator: " | ")). Run Repair content before launch.")
            }
            throw BuildError.preflightFailed(details.joined(separator: " || "))
        }
    }

    /// Spawns `npm run dev` after `runStartupGate()` succeeds. Caller must not call concurrently with another dev server.
    func spawnDevServerProcess() throws -> AsyncStream<String> {
        if case .running = state {
            if let existing = process, existing.isRunning {
                throw BuildError.alreadyRunning
            }
            self.process = nil
            self.state = .stopped
        }

        let proc = Process()
        proc.currentDirectoryURL = RepoConstants.repoRoot
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["npm", "run", "dev"]
        proc.environment = subprocessEnvironment()
        // GUI apps often hand children a useless stdin; many CLIs exit when
        // stdin hits EOF. Detach from the app tty via /dev/null.
        proc.standardInput = try? FileHandle(
            forReadingFrom: URL(fileURLWithPath: "/dev/null", isDirectory: false)
        )

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        let stream = AsyncStream<String> { continuation in
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                    continuation.yield(String(line))
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                    if let classified = Self.classifyKnownDevServerError(String(line)) {
                        continuation.yield("⚠︎ [SubtextLaunchError] " + classified)
                    }
                    continuation.yield("⚠︎ " + line)
                }
            }
            proc.terminationHandler = { p in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish()
            }
        }

        do {
            try proc.run()
        } catch {
            throw BuildError.launchFailed("\(error)")
        }

        self.process = proc
        self.state = .running(pid: proc.processIdentifier)
        return stream
    }

    /// Starts `npm run dev`. When `reapingOrphans` is true, kills matching repo Astro dev PIDs first, then gate + spawn.
    func startDev(reapingOrphans: Bool = true) throws -> AsyncStream<String> {
        if reapingOrphans {
            _ = stopAllAstroForCurrentRepo()
        }
        try runStartupGate()
        return try spawnDevServerProcess()
    }

    func runPreflight(validateOnly: Bool) -> PreflightReport {
        let repoReport = RepoValidator.validateRepo(at: RepoConstants.repoRoot)
        var issues = validateProjectFrontmatterPreflight()
        for blocking in repoReport.blockingIssues {
            issues.insert(PreflightIssue(fileName: "repo", reason: blocking), at: 0)
        }
        let repairableChanges = validateOnly ? detectRepairableProjectChanges() : []
        return PreflightReport(
            issues: issues,
            repairableChanges: repairableChanges,
            repoWarnings: repoReport.warnings
        )
    }

    @discardableResult
    func applyPreflightRepairs() -> [String] {
        migrateLegacyProjectBlocksPreflight()
    }

    func runHealthCheck(includeBuild: Bool) throws -> AsyncStream<BuildEvent> {
        try runHealthCheckScript(includeBuild: includeBuild)
        let report = runPreflight(validateOnly: true)
        if !report.isHealthy {
            let summary = report.issues.prefix(4).map { "\($0.fileName): \($0.reason)" }.joined(separator: " | ")
            let repairs = report.repairableChanges.prefix(4).joined(separator: " | ")
            throw BuildError.preflightFailed([summary, repairs].filter { !$0.isEmpty }.joined(separator: " || "))
        }
        if includeBuild {
            return try runBuild()
        }
        return AsyncStream<BuildEvent> { continuation in
            continuation.yield(.line("Health check passed"))
            continuation.yield(.finished(exitCode: 0))
            continuation.finish()
        }
    }

    private func runHealthCheckScript(includeBuild: Bool = false) throws {
        let scriptURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "scripts", directoryHint: .isDirectory)
            .appending(path: "health-check.sh", directoryHint: .notDirectory)
        guard FileManager.default.fileExists(atPath: scriptURL.path(percentEncoded: false)) else {
            return
        }

        let proc = Process()
        proc.currentDirectoryURL = RepoConstants.repoRoot
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["bash", scriptURL.path(percentEncoded: false), RepoConstants.repoRoot.path(percentEncoded: false)]
        if includeBuild {
            args.append("--with-build")
        }
        proc.arguments = args
        proc.environment = subprocessEnvironment()

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            throw BuildError.preflightFailed("Could not run health-check.sh: \(error.localizedDescription)")
        }
        let (stdout, stderr) = readPipesToEndAndWait(outPipe: outPipe, errPipe: errPipe, proc)
        if proc.terminationStatus != 0 {
            let errTrim = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let outTrim = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = errTrim.isEmpty ? outTrim : errTrim
            throw BuildError.preflightFailed(message.isEmpty ? "Health check script failed." : message)
        }
    }

    /// Sends SIGTERM and waits until the dev server process exits (or was already gone).
    func stop() async {
        guard let proc = process else {
            state = .stopped
            return
        }
        if proc.isRunning {
            proc.terminate()
            await Task.detached { [proc] in
                proc.waitUntilExit()
            }.value
        }
        process = nil
        state = .stopped
    }

    /// Hard shutdown for app quit: stop tracked process, reap repo Astro PIDs, brief wait, SIGKILL stragglers.
    func shutdownForQuit() async {
        await stop()
        _ = stopAllAstroForCurrentRepo()
    }

    /// Stops all repo-scoped Astro dev processes, including servers started
    /// outside Subtext, while avoiding unrelated Node processes.
    func stopAllAstroForCurrentRepo() -> StopAllResult {
        let candidatePIDs = discoverRepoScopedAstroDevPIDs()
        guard !candidatePIDs.isEmpty else {
            if let proc = process, !proc.isRunning {
                process = nil
                state = .stopped
            }
            return StopAllResult(matchedPIDs: [], gracefulStops: 0, forcedStops: 0, failures: [])
        }

        var forcedStops = 0
        var failures: [String] = []

        for pid in candidatePIDs {
            if kill(pid, SIGTERM) != 0 {
                failures.append("SIGTERM failed for pid \(pid): errno \(errno)")
            }
        }

        Thread.sleep(forTimeInterval: 0.35)

        let remainingAfterSIGTERM = candidatePIDs.filter { isPIDRunning($0) }
        for pid in remainingAfterSIGTERM {
            if kill(pid, SIGKILL) == 0 {
                forcedStops += 1
            } else {
                failures.append("SIGKILL failed for pid \(pid): errno \(errno)")
            }
        }

        let gracefulStops = max(candidatePIDs.count - remainingAfterSIGTERM.count, 0)

        if case .running(let trackedPID) = state, candidatePIDs.contains(trackedPID) {
            process = nil
            state = .stopped
        } else if let proc = process, !proc.isRunning {
            process = nil
            state = .stopped
        }

        return StopAllResult(
            matchedPIDs: candidatePIDs,
            gracefulStops: gracefulStops,
            forcedStops: forcedStops,
            failures: failures
        )
    }

    // MARK: - One-shot builds

    /// Event yielded by `runBuild` — a single line of output, then a
    /// terminal `.finished` carrying the `npm run build` exit code.
    enum BuildEvent: Sendable {
        case line(String)
        case finished(exitCode: Int32)
    }

    /// Runs `npm run build` once and streams stdout/stderr as events. The
    /// stream ends with `.finished(exitCode:)` so the caller always knows
    /// whether the build succeeded.
    ///
    /// Unlike `startDev`, this does not share state with the long-running
    /// dev server; it spawns a detached `Process` so the caller can pipe
    /// the output into a publish log while the dev server keeps running.
    func runBuild() throws -> AsyncStream<BuildEvent> {
        let proc = Process()
        proc.currentDirectoryURL = RepoConstants.repoRoot
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["npm", "run", "build"]
        proc.environment = subprocessEnvironment()

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        let stream = AsyncStream<BuildEvent> { continuation in
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                for line in String(decoding: data, as: UTF8.self)
                    .split(separator: "\n", omittingEmptySubsequences: false)
                where !line.isEmpty {
                    continuation.yield(.line(String(line)))
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                for line in String(decoding: data, as: UTF8.self)
                    .split(separator: "\n", omittingEmptySubsequences: false)
                where !line.isEmpty {
                    continuation.yield(.line("⚠︎ " + line))
                }
            }
            proc.terminationHandler = { p in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.yield(.finished(exitCode: p.terminationStatus))
                continuation.finish()
            }
        }

        do {
            try proc.run()
        } catch {
            throw BuildError.launchFailed("\(error)")
        }

        return stream
    }

    // MARK: - Preflight

    private func validateProjectFrontmatterPreflight() -> [PreflightIssue] {
        let fm = FileManager.default
        let dir = RepoConstants.projectsDirectory
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        let requiredKeys = ["title", "slug", "description", "date", "category", "tags"]
        var issues: [PreflightIssue] = []

        for file in files where file.pathExtension.lowercased() == "mdx" {
            guard let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
            guard let frontmatter = extractFrontmatter(raw) else {
                issues.append(PreflightIssue(fileName: file.lastPathComponent, reason: "missing frontmatter block"))
                continue
            }

            for key in requiredKeys where !frontmatterContainsKey(key, in: frontmatter) {
                issues.append(PreflightIssue(fileName: file.lastPathComponent, reason: "missing required field '\(key)'"))
            }

            if let slug = frontmatterScalarValue("slug", in: frontmatter), slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(PreflightIssue(fileName: file.lastPathComponent, reason: "slug must not be empty"))
            }

            issues.append(contentsOf: validateRequiredBlockFields(in: frontmatter, fileName: file.lastPathComponent))
        }

        return issues
    }

    private func validateRequiredBlockFields(in frontmatter: String, fileName: String) -> [PreflightIssue] {
        let lines = frontmatter.components(separatedBy: .newlines)
        var issues: [PreflightIssue] = []

        struct BlockScan {
            var type: String?
            var fields: [String: String] = [:]
            var sourceKind: String?
            var sourceVideoId: String?
            var sourceSrc: String?
        }

        func finalize(_ block: BlockScan, index: Int) -> [PreflightIssue] {
            guard let type = block.type else { return [] }
            var found: [PreflightIssue] = []

            func isBlank(_ value: String?) -> Bool {
                guard let value else { return true }
                return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            switch type {
            case "videoShowcase":
                let kind = block.sourceKind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if kind == "youtube", isBlank(block.sourceVideoId) {
                    found.append(PreflightIssue(fileName: fileName, reason: "blocks[\(index)] videoShowcase.source.videoId must not be empty for youtube"))
                }
                if kind == "file", isBlank(block.sourceSrc) {
                    found.append(PreflightIssue(fileName: fileName, reason: "blocks[\(index)] videoShowcase.source.src must not be empty for file"))
                }
            case "cta":
                if isBlank(block.fields["title"]) {
                    found.append(PreflightIssue(fileName: fileName, reason: "blocks[\(index)] cta.title must not be empty"))
                }
            case "quote":
                if isBlank(block.fields["quote"]) {
                    found.append(PreflightIssue(fileName: fileName, reason: "blocks[\(index)] quote.quote must not be empty"))
                }
            default:
                break
            }
            return found
        }

        var current: BlockScan?
        var currentBlockIndex = -1
        var inSource = false

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("- type:") {
                if let current {
                    issues.append(contentsOf: finalize(current, index: currentBlockIndex))
                }
                currentBlockIndex += 1
                inSource = false
                var next = BlockScan()
                next.type = scalarValue(from: trimmed)
                current = next
                continue
            }

            guard var block = current else { continue }

            if trimmed.hasPrefix("source:") {
                inSource = true
                current = block
                continue
            }

            if inSource, trimmed.hasPrefix("- ") {
                inSource = false
            }

            if inSource {
                if trimmed.hasPrefix("kind:") { block.sourceKind = scalarValue(from: trimmed) }
                if trimmed.hasPrefix("videoId:") { block.sourceVideoId = scalarValue(from: trimmed) }
                if trimmed.hasPrefix("src:") { block.sourceSrc = scalarValue(from: trimmed) }
            }

            if let colon = trimmed.firstIndex(of: ":"), !trimmed.hasPrefix("- ") {
                let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                block.fields[key] = value
            }

            current = block
        }

        if let current {
            issues.append(contentsOf: finalize(current, index: currentBlockIndex))
        }

        return issues
    }

    private func scalarValue(from line: String) -> String {
        guard let sep = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: sep)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private func extractFrontmatter(_ raw: String) -> String? {
        guard let range = raw.range(of: #"(?ms)^---\s*\n(.*?)\n---\s*"#, options: .regularExpression) else {
            return nil
        }
        let block = String(raw[range])
        return block
            .replacingOccurrences(of: #"(?m)^---\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func frontmatterContainsKey(_ key: String, in frontmatter: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let pattern = "(?m)^" + escaped + #"\s*:"# 
        return frontmatter.range(of: pattern, options: .regularExpression) != nil
    }

    private func frontmatterScalarValue(_ key: String, in frontmatter: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let pattern = "(?m)^" + escaped + #"\s*:\s*(.+)$"#
        guard let range = frontmatter.range(of: pattern, options: .regularExpression) else { return nil }
        let line = String(frontmatter[range])
        guard let sep = line.firstIndex(of: ":") else { return nil }
        return String(line[line.index(after: sep)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectRepairableProjectChanges() -> [String] {
        let dir = RepoConstants.projectsDirectory
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var changes: [String] = []
        for file in files where file.pathExtension.lowercased() == "mdx" {
            guard let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
            guard let frontmatter = extractFrontmatter(raw) else { continue }
            let legacyHits = LegacyBlockMigration.scanLegacyBlockTypes(in: frontmatter)
            for hit in legacyHits {
                changes.append(
                    "\(file.lastPathComponent): blocks[\(hit.index)] legacy block type '\(hit.legacyType)' -> '\(hit.canonicalType)'"
                )
            }
            if frontmatter.range(of: #"(?m)^(\s*)videoId:\s*["']?\s*["']?\s*$"#, options: .regularExpression) != nil {
                changes.append("\(file.lastPathComponent): empty videoId")
            }
        }
        return changes
    }

    private func migrateLegacyProjectBlocksPreflight() -> [String] {
        let dir = RepoConstants.projectsDirectory
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var repairedFiles: [String] = []

        for file in files where file.pathExtension.lowercased() == "mdx" {
            guard var raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
            var changed = false
            if let frontmatter = extractFrontmatter(raw) {
                let migration = LegacyBlockMigration.migrate(frontmatter: frontmatter)
                if migration.didChange {
                    raw = raw.replacingOccurrences(of: frontmatter, with: migration.content)
                    changed = true
                }
            }

            if changed {
                try? raw.write(to: file, atomically: true, encoding: .utf8)
                repairedFiles.append(file.lastPathComponent)
            }
        }
        return repairedFiles
    }

    static func classifyKnownDevServerError(_ line: String) -> String? {
        if line.contains("[InvalidContentEntryDataError]") {
            return "Astro content schema validation failed"
        }
        return nil
    }

    private func discoverRepoScopedAstroDevPIDs() -> [Int32] {
        let psOutput = (try? runSystemCommand("/bin/ps", ["-axo", "pid=,command="])) ?? ""
        guard !psOutput.isEmpty else { return [] }

        var matched: Set<Int32> = []
        for rawLine in psOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let command = String(parts[1]).lowercased()

            // Restrict to astro dev invocations.
            let isAstroProcess = command.contains("astro")
            let isDevInvocation = command.contains("astro dev")
                || command.contains("astro.js dev")
                || command.contains(" dev --host")
                || command.hasSuffix(" dev")
            guard isAstroProcess && isDevInvocation else { continue }

            guard let cwd = processWorkingDirectory(pid: pid),
                  cwd.hasPrefix(RepoConstants.repoRoot.path(percentEncoded: false)) else { continue }
            matched.insert(pid)
        }

        return matched.sorted()
    }

    private func processWorkingDirectory(pid: Int32) -> String? {
        let output = try? runSystemCommand("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])
        guard let output else { return nil }
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return nil
    }

    private func isPIDRunning(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private func runSystemCommand(_ executable: String, _ arguments: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        proc.environment = subprocessEnvironment()

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        try proc.run()
        let (out, _) = readPipesToEndAndWait(outPipe: outPipe, errPipe: errPipe, proc)
        return out
    }
}
