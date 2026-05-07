import XCTest
@testable import Subtext

@MainActor
final class CMSStoreRemoteSyncTests: XCTestCase {
    func testCanCheckRemoteSplashFalseWhenMicroblogDisabled() {
        let store = CMSStore()
        store.siteSettings.microblog = MicroblogSettings(
            pageURL: "https://micro.blog/example/home",
            enabled: false
        )

        XCTAssertFalse(store.canCheckRemoteSplash)
    }

    func testCanCheckRemoteSplashFalseWhenPageURLMissing() {
        let store = CMSStore()
        store.siteSettings.microblog = MicroblogSettings(pageURL: "", enabled: true)

        XCTAssertFalse(store.canCheckRemoteSplash)
    }

    func testDirtyHomeRequiresPromptBeforeApplyingRemote() {
        let store = CMSStore()
        store.splashContent.ctas.append(
            SplashCTA(id: "local", name: "Local", heading: "", subtitle: "", href: "/local")
        )
        store.applyRemoteSplashForPreview(remoteSplash())

        XCTAssertTrue(store.shouldPromptBeforeApplyingRemoteSplash)
    }

    func testApplyPendingRemoteSplashUpdatesEditorAndBaseline() {
        let store = CMSStore()
        let remote = remoteSplash()
        store.applyRemoteSplashForPreview(remote)

        store.applyPendingRemoteSplash()

        XCTAssertEqual(store.splashContent, remote)
        XCTAssertEqual(store.originalSplash, remote)
        XCTAssertFalse(store.remoteSplashCheckState.hasRemoteChange)
        XCTAssertNil(store.remoteSplashCheckState.pendingRemoteSplash)
    }

    private func remoteSplash() -> SplashContent {
        SplashContent(
            sections: [],
            ctas: [SplashCTA(id: "remote", name: "Remote", heading: "", subtitle: "", href: "/remote")]
        )
    }
}
