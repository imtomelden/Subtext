import Foundation
import Observation

/// Drives the "one-button publish" flow: save any in-memory edits → run
/// `npm run build` → if it succeeds, commit everything with a supplied
/// message and push to origin.
///
/// Every phase writes into `log` so the UI can stream a live readout.
/// `phase` drives the inline progress strip; failures park the flow with
/// a `.failed` phase carrying a short description.
@Observable
@MainActor
final class PublishController {
    enum Phase: Equatable {
        case idle
        case saving
        case building
        case committing
        case pushing
        case succeeded
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .saving, .building, .committing, .pushing: true
            default: false
            }
        }

        var displayName: String {
            switch self {
            case .idle: "Ready"
            case .saving: "Saving edits…"
            case .building: "Running `npm run build`…"
            case .committing: "Committing…"
            case .pushing: "Pushing to origin…"
            case .succeeded: "Published"
            case .failed(let reason): reason
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var log: [String] = []
    private let maxLogLines: Int = 2000
    private var runTask: Task<Void, Never>?

    private let buildService = BuildService()

    var isBusy: Bool { phase.isBusy }

    /// Kick off the full pipeline. Safe to call only when `!isBusy`.
    func publish(store: CMSStore, git: GitController, message: String) {
        guard !isBusy else { return }
        runTask?.cancel()
        phase = .idle
        log.removeAll()

        runTask = Task { [weak self, weak store, weak git] in
            guard let self, let store, let git else { return }
            await self.runPipeline(store: store, git: git, message: message)
        }
    }

    func reset() {
        guard !isBusy else { return }
        phase = .idle
        log.removeAll()
    }

    // MARK: - Private

    private func runPipeline(
        store: CMSStore,
        git: GitController,
        message: String
    ) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .failed("Commit message is empty.")
            return
        }

        // 1. Save any dirty files so the build picks up the latest edits.
        phase = .saving
        append("▸ Saving unsaved edits…")
        if store.isSplashDirty { await store.saveSplash() }
        if store.isSiteDirty { await store.saveSite() }
        for doc in store.projects where store.isProjectDirty(doc.fileName) {
            await store.saveProject(doc.fileName)
        }
        if store.lastError != nil {
            phase = .failed("A file failed to save — fix the error and retry.")
            return
        }

        // 2. Run the build, streaming output into the log.
        phase = .building
        append("▸ Running `npm run build`…")
        let exitCode: Int32
        do {
            let stream = try await buildService.runBuild()
            exitCode = await drainBuild(stream)
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            phase = .failed("Build launch failed: \(reason)")
            append("⚠︎ \(reason)")
            return
        }

        guard exitCode == 0 else {
            phase = .failed("Build failed (exit \(exitCode)). Publish aborted — nothing pushed.")
            append("⚠︎ Build exited \(exitCode); not committing.")
            return
        }
        append("✓ Build succeeded.")

        // 3. Commit.
        phase = .committing
        append("▸ Committing…")
        git.commitAndPush(message: trimmed)

        // 4. Poll the git controller until it finishes.
        phase = .pushing
        while git.isBusy {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
        }

        switch git.outcome {
        case .success(let text):
            append("✓ \(text)")
            phase = .succeeded
        case .failure(let text):
            append("⚠︎ \(text)")
            phase = .failed(text)
        case .none:
            phase = .succeeded
        }
    }

    private func drainBuild(_ stream: AsyncStream<BuildService.BuildEvent>) async -> Int32 {
        var exitCode: Int32 = -1
        for await event in stream {
            switch event {
            case .line(let text):
                append(text)
            case .finished(let code):
                exitCode = code
            }
        }
        return exitCode
    }

    private func append(_ line: String) {
        log.append(line)
        if log.count > maxLogLines {
            log.removeFirst(log.count - maxLogLines)
        }
    }
}
