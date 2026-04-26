import XCTest
@testable import Subtext

@MainActor
final class DevServerControllerTests: XCTestCase {
    func testInitialPhaseIsStopped() {
        let c = DevServerController()
        XCTAssertEqual(c.phase, .stopped)
    }

    func testStoppedPhaseIsNotTransitional() {
        XCTAssertFalse(DevServerPhase.stopped.isTransitional)
    }

    func testPreflightingIsTransitional() {
        XCTAssertTrue(DevServerPhase.preflighting.isTransitional)
    }

    func testRunningDisplayPort() {
        let p = DevServerPhase.running(pid: 42, port: 4321)
        XCTAssertEqual(p.displayPort, 4321)
        XCTAssertTrue(p.isRunning)
    }
}
