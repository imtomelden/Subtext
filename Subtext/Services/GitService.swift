import Foundation

private let gitDefaultCommandTimeoutSeconds: TimeInterval = 30
private let gitPushTimeoutSeconds: TimeInterval = 90

/// Actor-isolated wrapper around the `git` binary. Runs commands against
/// `RepoConstants.repoRoot` and returns parsed state so the UI never has to
/// spawn processes directly.
///
/// Every command is a one-shot blocking `Process` (git commands are quick);
/// the long-running dev-server lives in `BuildService` with its own stream.
actor GitService {
    /// Snapshot of `git status` — everything the commit panel needs.
    struct Status: Equatable, Sendable {
        var branch: String
        var upstream: String?
        var ahead: Int
        var behind: Int
        /// File entries parsed from `git status --porcelain`.
        var entries: [Entry]

        var isClean: Bool { entries.isEmpty }
        var stagedCount: Int { entries.filter { $0.isStaged }.count }
        var modifiedCount: Int { entries.filter { !$0.isStaged && $0.change != .untracked }.count }
        var untrackedCount: Int { entries.filter { $0.change == .untracked }.count }

        static let empty = Status(branch: "-", upstream: nil, ahead: 0, behind: 0, entries: [])
    }

    struct Entry: Equatable, Identifiable, Sendable {
        enum Change: String, Sendable {
            case modified
            case added
            case deleted
            case renamed
            case copied
            case untracked
            case unmerged
            case other
        }

        let path: String
        let indexCode: Character
        let worktreeCode: Character

        var id: String { path }

        var isStaged: Bool {
            indexCode != " " && indexCode != "?"
        }

        var change: Change {
            if indexCode == "?" && worktreeCode == "?" { return .untracked }
            if indexCode == "U" || worktreeCode == "U" { return .unmerged }
            let code = isStaged ? indexCode : worktreeCode
            switch code {
            case "M": return .modified
            case "A": return .added
            case "D": return .deleted
            case "R": return .renamed
            case "C": return .copied
            default: return .other
            }
        }
    }

    enum GitError: LocalizedError {
        case binaryNotFound
        case commandFailed(command: String, exitCode: Int32, stderr: String)
        case commandTimedOut(command: String, timeoutSeconds: TimeInterval, stderr: String)
        case notARepo(path: String)
        case nothingToCommit
        case noUpstream(branch: String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "git was not found on this Mac (install Xcode Command Line Tools)."
            case .commandFailed(let command, let code, let stderr):
                return "`git \(command)` exited \(code)\n\n\(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
            case .commandTimedOut(let command, let timeoutSeconds, let stderr):
                let rounded = Int(timeoutSeconds.rounded())
                let context = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                let hint = "Likely waiting on remote auth, a network connection, or a hook. Try `git push --verbose` in Terminal for details."
                if context.isEmpty {
                    return "`git \(command)` timed out after \(rounded)s.\n\n\(hint)"
                }
                return "`git \(command)` timed out after \(rounded)s.\n\n\(context)\n\n\(hint)"
            case .notARepo(let path):
                return "\(path) is not a git repository."
            case .nothingToCommit:
                return "Nothing to commit — the working tree is clean."
            case .noUpstream(let branch):
                return "The current branch (\(branch)) has no upstream. Push once from the terminal, or tap Push to set it automatically."
            }
        }
    }

    // MARK: - Public API

    /// Reads the current status. Safe to call repeatedly; cheap when the
    /// repo is small.
    func status() async throws -> Status {
        try ensureRepo()

        let branch = try await run(["rev-parse", "--abbrev-ref", "HEAD"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let upstream: String? = try? await run(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var ahead = 0, behind = 0
        if upstream != nil {
            let rev = (try? await run(["rev-list", "--left-right", "--count", "HEAD...@{u}"])) ?? ""
            let parts = rev.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\t", omittingEmptySubsequences: false)
            if parts.count == 2 {
                ahead = Int(parts[0]) ?? 0
                behind = Int(parts[1]) ?? 0
            }
        }

        let porcelain = try await run(["status", "--porcelain=v1", "--untracked-files=all", "-z"])
        let entries = parsePorcelain(porcelain)

        return Status(
            branch: branch.isEmpty ? "(detached)" : branch,
            upstream: upstream,
            ahead: ahead,
            behind: behind,
            entries: entries
        )
    }

    /// Stages every changed + untracked file and creates a commit.
    /// Returns the new status after committing.
    @discardableResult
    func commitAll(message: String) async throws -> Status {
        try ensureRepo()

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GitError.commandFailed(command: "commit", exitCode: 1, stderr: "Commit message cannot be empty.")
        }

        let current = try await status()
        guard !current.isClean else { throw GitError.nothingToCommit }

        try await run(["add", "-A"])
        try await run(["commit", "-m", trimmed])
        return try await status()
    }

    /// Unstages everything, then stages only `paths` (repo-relative), and commits.
    @discardableResult
    func commit(message: String, stagingPaths paths: [String]) async throws -> Status {
        try ensureRepo()
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GitError.commandFailed(command: "commit", exitCode: 1, stderr: "Commit message cannot be empty.")
        }
        let unique = Array(Set(paths)).sorted()
        guard !unique.isEmpty else {
            throw GitError.commandFailed(command: "commit", exitCode: 1, stderr: "No files selected to commit.")
        }

        try await run(["reset", "HEAD"])
        for path in unique {
            try await run(["add", "--", path])
        }
        let staged = try await status().entries.filter(\.isStaged)
        guard !staged.isEmpty else {
            throw GitError.commandFailed(command: "commit", exitCode: 1, stderr: "Nothing was staged — check your file selection.")
        }
        try await run(["commit", "-m", trimmed])
        return try await status()
    }

    /// Pushes the current branch to its upstream. Auto-sets upstream on
    /// first push.
    @discardableResult
    func push() async throws -> Status {
        try ensureRepo()

        let current = try await status()
        if current.upstream == nil {
            // No upstream yet — push & set.
            try await run(
                ["push", "--set-upstream", "origin", current.branch],
                timeoutSeconds: gitPushTimeoutSeconds,
                useBatchModeSSH: true
            )
        } else {
            try await run(
                ["push"],
                timeoutSeconds: gitPushTimeoutSeconds,
                useBatchModeSSH: true
            )
        }
        return try await status()
    }

    /// Convenience that commits staged + unstaged + untracked in one shot,
    /// then pushes. Returns the final status.
    @discardableResult
    func commitAndPush(message: String) async throws -> Status {
        _ = try await commitAll(message: message)
        return try await push()
    }

    /// Returns all local branch names, current branch first.
    func branches() async throws -> [String] {
        try ensureRepo()
        let raw = try await run(["branch", "--list", "--format=%(refname:short)"])
        let all = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let current = (try? await status().branch) ?? ""
        return ([current] + all.filter { $0 != current }).filter { !$0.isEmpty }
    }

    /// Checks out `branch`. Throws if there are conflicts or the branch doesn't exist.
    func checkout(branch: String) async throws {
        try ensureRepo()
        try await run(["checkout", branch])
    }

    /// Creates and checks out a new branch from the current HEAD.
    func createBranchAndCheckout(name: String) async throws {
        try ensureRepo()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GitError.commandFailed(command: "checkout -b", exitCode: 1, stderr: "Branch name cannot be empty.")
        }
        try await run(["checkout", "-b", trimmed])
    }

    func hasStash() async throws -> Bool {
        try ensureRepo()
        let out = try await run(["stash", "list"])
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func stashPush() async throws {
        try ensureRepo()
        try await run(["stash", "push", "-u", "-m", "Subtext"])
    }

    func stashPop() async throws {
        try ensureRepo()
        try await run(["stash", "pop"])
    }

    /// Returns the unified diff for `path`. Tries staged diff, then HEAD diff.
    /// Returns nil for untracked (new) files with no prior content.
    func diff(path: String) async throws -> String? {
        try ensureRepo()
        // Staged (index vs HEAD) first — catches `git add`-ed files.
        let staged = (try? await run(["diff", "--cached", "--", path])) ?? ""
        if !staged.isEmpty { return staged }
        // Working tree vs HEAD.
        let working = (try? await run(["diff", "HEAD", "--", path])) ?? ""
        if !working.isEmpty { return working }
        return nil   // untracked — caller can show "new file" placeholder
    }

    /// Fetches from origin then fast-forwards the current branch.
    /// Fails cleanly (throws) rather than creating a merge commit.
    @discardableResult
    func fetchAndPull() async throws -> Status {
        try ensureRepo()
        try await run(["fetch", "--quiet"], timeoutSeconds: gitPushTimeoutSeconds, useBatchModeSSH: true)
        _ = try? await run(["pull", "--ff-only", "--quiet"])
        return try await status()
    }

    // MARK: - Internals

    private func ensureRepo() throws {
        let gitDir = RepoConstants.repoRoot.appending(path: ".git", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: gitDir.path(percentEncoded: false)) else {
            throw GitError.notARepo(path: RepoConstants.repoRoot.path(percentEncoded: false))
        }
    }

    /// Runs `git <args>` in the repo root and returns stdout. Throws on a
    /// non-zero exit. Captures stderr for diagnostics.
    @discardableResult
    private func run(
        _ args: [String],
        timeoutSeconds: TimeInterval = gitDefaultCommandTimeoutSeconds,
        useBatchModeSSH: Bool = false
    ) async throws -> String {
        let process = Process()
        process.currentDirectoryURL = RepoConstants.repoRoot
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args

        // Give git a predictable PATH so it can find helpers without inheriting
        // a potentially pruned agent environment.
        var env = ProcessInfo.processInfo.environment
        let defaultPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        if let existing = env["PATH"], !existing.isEmpty {
            env["PATH"] = existing + ":" + defaultPaths
        } else {
            env["PATH"] = defaultPaths
        }
        // Disable interactive credential prompts — UIs can't answer them.
        env["GIT_TERMINAL_PROMPT"] = "0"
        if useBatchModeSSH {
            // Fail immediately if SSH credentials are unavailable.
            let existing = env["GIT_SSH_COMMAND"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing, !existing.isEmpty {
                env["GIT_SSH_COMMAND"] = "\(existing) -oBatchMode=yes"
            } else {
                env["GIT_SSH_COMMAND"] = "ssh -oBatchMode=yes"
            }
        }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw GitError.binaryNotFound
        }

        // Read both pipes concurrently to avoid blocking on a full buffer.
        async let stdoutTask: Data = Task.detached {
            outPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        async let stderrTask: Data = Task.detached {
            errPipe.fileHandleForReading.readDataToEndOfFile()
        }.value

        let command = args.joined(separator: " ")
        let didTimeout = try await waitForExit(process, timeoutSeconds: timeoutSeconds)

        let stdoutData = await stdoutTask
        let stderrData = await stderrTask

        let stdout = String(decoding: stdoutData, as: UTF8.self)
        let stderr = String(decoding: stderrData, as: UTF8.self)
        let combinedOutput = stderr.isEmpty ? stdout : stderr

        if didTimeout {
            throw GitError.commandTimedOut(
                command: command,
                timeoutSeconds: timeoutSeconds,
                stderr: combinedOutput
            )
        }

        guard process.terminationStatus == 0 else {
            throw GitError.commandFailed(
                command: command,
                exitCode: process.terminationStatus,
                stderr: combinedOutput
            )
        }

        return stdout
    }

    /// Waits for process exit with timeout. Returns `true` when timed out.
    private func waitForExit(_ process: Process, timeoutSeconds: TimeInterval) async throws -> Bool {
        let startedAt = Date()
        while process.isRunning {
            if Task.isCancelled {
                process.interrupt()
                process.terminate()
                throw CancellationError()
            }

            if Date().timeIntervalSince(startedAt) >= timeoutSeconds {
                process.interrupt()
                process.terminate()
                process.waitUntilExit()
                return true
            }

            try await Task.sleep(nanoseconds: 200_000_000)
        }

        process.waitUntilExit()
        return false
    }

    /// Parses the NUL-separated output of `git status --porcelain=v1 -z`.
    /// Each record is `XY <space> path` where `X` is the index status and
    /// `Y` the worktree status.
    private func parsePorcelain(_ raw: String) -> [Entry] {
        guard !raw.isEmpty else { return [] }
        var entries: [Entry] = []

        // Records are NUL-delimited; rename/copy records carry a second NUL
        // for the original path that we ignore.
        var tokens = raw.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
        while !tokens.isEmpty {
            let token = tokens.removeFirst()
            guard token.count >= 3 else { continue }
            let codes = token.prefix(2)
            let indexCode = codes.first ?? " "
            let worktreeCode = codes.dropFirst().first ?? " "
            // Skip the single space that separates codes from path.
            let pathStart = token.index(token.startIndex, offsetBy: 3)
            let path = String(token[pathStart...])
            if indexCode == "R" || indexCode == "C" {
                // Consume original path.
                if !tokens.isEmpty { tokens.removeFirst() }
            }
            entries.append(Entry(path: path, indexCode: indexCode, worktreeCode: worktreeCode))
        }
        return entries
    }
}
