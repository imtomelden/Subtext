import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class MicroblogStore {

    enum SyncState: Equatable {
        case idle
        case pushing
        case success
        case failed(String)
    }

    var syncState: SyncState = .idle

    private let service = MicroblogService()
    private static let logger = Logger(subsystem: "com.subtext.app", category: "microblog")

    // MARK: - Token (Keychain-backed)

    var hasToken: Bool {
        KeychainService.read(key: "microblog.token") != nil
    }

    func saveToken(_ value: String) throws {
        try KeychainService.save(key: "microblog.token", value: value)
    }

    func clearToken() throws {
        try KeychainService.delete(key: "microblog.token")
    }

    private var token: String? {
        KeychainService.read(key: "microblog.token")
    }

    // MARK: - Push (called by CMSStore.performSaveSplash)

    func pushSplash(_ content: SplashContent, settings: MicroblogSettings) async {
        guard settings.enabled else { return }
        guard let token else {
            syncState = .failed("No Micro.blog token stored.")
            return
        }
        syncState = .pushing
        do {
            try await service.updateSplash(content, token: token, pageURL: settings.pageURL)
            syncState = .success
            Self.logger.info("Splash pushed to Micro.blog.")
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            syncState = .failed(msg)
            Self.logger.error("Micro.blog push failed: \(msg, privacy: .public)")
        }
    }

    // MARK: - Create (one-time migration)

    /// Creates the Micro.blog page from current splash content and returns
    /// the page URL (from the Micropub Location header).
    func createSplashPage(_ content: SplashContent, slug: String) async throws -> String {
        guard let token else {
            throw MicroblogService.MicroblogError.missingCredentials
        }
        return try await service.createSplashPage(content, slug: slug, token: token)
    }

    // MARK: - Pull (for settings UI verification)

    func fetchSplash(settings: MicroblogSettings) async throws -> SplashContent {
        guard let token else {
            throw MicroblogService.MicroblogError.missingCredentials
        }
        return try await service.fetchSplash(token: token, pageURL: settings.pageURL)
    }
}
