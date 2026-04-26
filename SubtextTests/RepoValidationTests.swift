import XCTest
@testable import Subtext

final class RepoValidationTests: XCTestCase {
    func testValidateRepoFailsWhenRequiredFilesMissing() throws {
        let root = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let report = RepoValidator.validateRepo(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.blockingIssues.contains { $0.contains("package.json") })
        XCTAssertTrue(report.blockingIssues.contains { $0.contains("src/content") })
    }

    func testValidateRepoPassesForExpectedShape() throws {
        let root = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try createFile(root.appending(path: "package.json"), contents: """
        {
          "scripts": { "dev": "astro dev" },
          "dependencies": { "astro": "^5.0.0" }
        }
        """)
        try FileManager.default.createDirectory(
            at: root.appending(path: "src/content/projects", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try createFile(root.appending(path: "src/content/splash.json"), contents: "{}")
        try createFile(root.appending(path: "src/content/site.json"), contents: "{}")
        try createFile(root.appending(path: "astro.config.mjs"), contents: "export default {}")

        let report = RepoValidator.validateRepo(at: root)
        XCTAssertTrue(report.isValid)
        XCTAssertTrue(report.blockingIssues.isEmpty)
    }

    private func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func createFile(_ url: URL, contents: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
