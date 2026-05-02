import Foundation
import Observation

/// Main-actor façade around `GitService`. Owns the cached status + in-flight
/// activity state used by `GitPanel` and the sidebar git pill.
@Observable
@MainActor
final class GitController {
    enum Activity: Equatable {
        case idle
        case loading
        case committing
        case pushing
        case syncing
        case checkingOut
        case stashing
    }

    enum Outcome: Equatable {
        case none
        case success(String)
        case failure(String)
    }

    private(set) var status: GitService.Status = .empty
    private(set) var activity: Activity = .idle
    private(set) var outcome: Outcome = .none
    private(set) var lastRefresh: Date?
    private(set) var availableBranches: [String] = []
    private(set) var hasStash: Bool = false

    private let service = GitService()
    private var currentTask: Task<Void, Never>?

    var isBusy: Bool { activity != .idle }
    var hasLocalChanges: Bool { !status.isClean }

    /// Refreshes `status`. Silent failures are surfaced via `outcome` so the
    /// sidebar pill can display a subtle warning.
    func refresh() {
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .loading
            defer { activity = .idle }
            do {
                status = try await service.status()
                hasStash = (try? await service.hasStash()) ?? false
                lastRefresh = Date()
                if case .failure = outcome { outcome = .none }
            } catch {
                status = .empty
                outcome = .failure(describe(error))
            }
        }
    }

    /// Commits either everything (`stagingPaths` nil) or only the given paths
    /// (after resetting the index and re-staging the selection).
    func commit(message: String, stagingPaths: Set<String>? = nil) {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .committing
            defer { activity = .idle }
            do {
                if let stagingPaths, !stagingPaths.isEmpty {
                    status = try await service.commit(message: message, stagingPaths: Array(stagingPaths))
                } else {
                    status = try await service.commitAll(message: message)
                }
                hasStash = (try? await service.hasStash()) ?? hasStash
                outcome = .success("Committed on \(status.branch).")
            } catch {
                outcome = .failure(describe(error))
            }
        }
    }

    /// Pushes the current branch to its upstream (auto-sets upstream on
    /// first push).
    func push() {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .pushing
            defer { activity = .idle }
            do {
                status = try await service.push()
                outcome = .success("Pushed \(status.branch) to \(status.upstream ?? "origin").")
            } catch {
                outcome = .failure(describe(error))
            }
        }
    }

    /// Commit + push in one flow. Fire-and-forget; observers watch
    /// `activity` / `outcome` to follow progress. For callers that need to
    /// chain off the *exact* completion (e.g. `PublishController` driving
    /// the publish pipeline), prefer `commitAndPushAwait(message:)` which
    /// reports phases through a callback and returns the resolved outcome.
    func commitAndPush(message: String, stagingPaths: Set<String>? = nil) {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            _ = await runCommitAndPush(message: message, stagingPaths: stagingPaths, onPhase: nil)
        }
    }

    /// Structured commit + push that returns once the push has either
    /// succeeded, failed, or thrown. Replaces the old "spin while
    /// `isBusy`" pattern from `PublishController` so we don't have a
    /// 200ms polling delay between push completion and the next phase.
    @discardableResult
    func commitAndPushAwait(
        message: String,
        stagingPaths: Set<String>? = nil,
        onPhase: ((Activity) -> Void)? = nil
    ) async -> Outcome {
        guard !isBusy else { return outcome }
        currentTask?.cancel()
        return await runCommitAndPush(message: message, stagingPaths: stagingPaths, onPhase: onPhase)
    }

    private func runCommitAndPush(
        message: String,
        stagingPaths: Set<String>?,
        onPhase: ((Activity) -> Void)?
    ) async -> Outcome {
        do {
            activity = .committing
            onPhase?(.committing)
            if let stagingPaths, !stagingPaths.isEmpty {
                _ = try await service.commit(message: message, stagingPaths: Array(stagingPaths))
            } else {
                _ = try await service.commitAll(message: message)
            }
            activity = .pushing
            onPhase?(.pushing)
            status = try await service.push()
            let result: Outcome = .success(
                "Committed + pushed to \(status.upstream ?? status.branch)."
            )
            outcome = result
            activity = .idle
            onPhase?(.idle)
            hasStash = (try? await service.hasStash()) ?? hasStash
            return result
        } catch {
            let result: Outcome = .failure(describe(error))
            outcome = result
            do {
                status = try await service.status()
                hasStash = (try? await service.hasStash()) ?? false
            } catch {
                // Keep previously shown failure.
            }
            activity = .idle
            onPhase?(.idle)
            return result
        }
    }

    func clearOutcome() {
        outcome = .none
    }

    /// Loads the list of local branches into `availableBranches`.
    func loadBranches() {
        Task { [weak self] in
            guard let self else { return }
            availableBranches = (try? await service.branches()) ?? []
        }
    }

    /// Checks out `branch`, then refreshes status.
    func checkout(to branch: String) {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .checkingOut
            defer { activity = .idle }
            do {
                try await service.checkout(branch: branch)
                status = try await service.status()
                hasStash = (try? await service.hasStash()) ?? false
                availableBranches = (try? await service.branches()) ?? availableBranches
                outcome = .success("Switched to \(branch).")
            } catch {
                outcome = .failure(describe(error))
            }
        }
    }

    /// Fetch + fast-forward pull. Updates `status` on success.
    func sync() {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .syncing
            defer { activity = .idle }
            do {
                status = try await service.fetchAndPull()
                hasStash = (try? await service.hasStash()) ?? false
                outcome = .success("Synced \(status.branch).")
            } catch {
                outcome = .failure(describe(error))
            }
        }
    }

    /// Returns the unified diff string for `path`, or nil for new/untracked files.
    func diff(path: String) async -> String? {
        try? await service.diff(path: path)
    }

    func createBranch(name: String) {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .checkingOut
            defer { activity = .idle }
            do {
                try await service.createBranchAndCheckout(name: name)
                status = try await service.status()
                hasStash = (try? await service.hasStash()) ?? false
                availableBranches = (try? await service.branches()) ?? availableBranches
                outcome = .success("Created branch \(name).")
            } catch {
                outcome = .failure(describe(error))
            }
        }
    }

    func stashChanges() {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .stashing
            defer { activity = .idle }
            do {
                try await service.stashPush()
                status = try await service.status()
                hasStash = (try? await service.hasStash()) ?? true
                outcome = .success("Stashed local changes.")
            } catch {
                outcome = .failure(describe(error))
            }
        }
    }

    func stashPop() {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .stashing
            defer { activity = .idle }
            do {
                try await service.stashPop()
                status = try await service.status()
                hasStash = (try? await service.hasStash()) ?? false
                outcome = .success("Applied stash.")
            } catch {
                outcome = .failure(describe(error))
            }
        }
    }

    private func describe(_ error: Error) -> String {
        if let gitError = error as? GitService.GitError {
            return describeGitError(gitError)
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func describeGitError(_ error: GitService.GitError) -> String {
        switch error {
        case .commandTimedOut:
            return """
            Push timed out. Git is likely waiting on credentials, network, or a repository hook.
            Try `git push --verbose` in Terminal to see where it blocks.
            """
        case .commandFailed(let command, _, let stderr):
            guard command.contains("push") else {
                return error.errorDescription ?? "Git command failed."
            }
            return describePushFailure(stderr: stderr)
        default:
            return error.errorDescription ?? "Git command failed."
        }
    }

    private func describePushFailure(stderr: String) -> String {
        let text = stderr.lowercased()
        if text.contains("permission denied") || text.contains("authentication failed") || text.contains("could not read from remote repository") {
            return """
            Push failed due to authentication. Re-authenticate your git remote credentials, then try again.
            """
        }
        if text.contains("could not resolve host") || text.contains("operation timed out") || text.contains("connection timed out") {
            return """
            Push failed due to a network issue reaching the remote. Check VPN/network access, then retry.
            """
        }
        if text.contains("pre-push hook") || text.contains("hook declined") || text.contains("hook") {
            return """
            Push was blocked by a git hook. Run `git push --verbose` in Terminal for full hook output.
            """
        }
        return """
        Push failed. Run `git push --verbose` in Terminal for detailed diagnostics.
        """
    }
}
