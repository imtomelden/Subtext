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
                lastRefresh = Date()
                if case .failure = outcome { outcome = .none }
            } catch {
                status = .empty
                outcome = .failure(describe(error))
            }
        }
    }

    /// Commits every local change (staged + unstaged + untracked) with
    /// `message`.
    func commit(message: String) {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            activity = .committing
            defer { activity = .idle }
            do {
                status = try await service.commitAll(message: message)
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

    /// Commit + push in one flow.
    func commitAndPush(message: String) {
        guard !isBusy else { return }
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                activity = .committing
                _ = try await service.commitAll(message: message)
                activity = .pushing
                status = try await service.push()
                outcome = .success("Committed + pushed to \(status.upstream ?? status.branch).")
            } catch {
                outcome = .failure(describe(error))
                do {
                    status = try await service.status()
                } catch {
                    // Keep previously shown failure.
                }
            }
            activity = .idle
        }
    }

    func clearOutcome() {
        outcome = .none
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
