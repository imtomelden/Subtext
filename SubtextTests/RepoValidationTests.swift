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

final class HomeMarkdownCompilerTests: XCTestCase {
    func testRoundTripSplashMarkdownSplash() throws {
        let compiler = HomeMarkdownCompiler()
        let original = SplashContent(
            sections: [
                SplashSection(
                    id: "hero",
                    heading: "I'm Tom",
                    subtitle: "Communicator.",
                    bodyParagraphs: ["Hello world", "Second paragraph"],
                    imagePosition: .left,
                    isHero: false,
                    visual: .photo(PhotoVisual(src: "/me.jpg", alt: "Me")),
                    transition: nil,
                    visualAlternates: nil
                )
            ],
            ctas: [
                SplashCTA(
                    id: "cta-projects",
                    name: "Projects CTA",
                    heading: "Projects",
                    subtitle: "Read work",
                    href: "/projects"
                )
            ]
        )

        let markdown = try compiler.splashToMarkdown(original)
        XCTAssertFalse(markdown.contains("```subtext-section"))
        XCTAssertFalse(markdown.contains("```subtext-cta"))
        XCTAssertFalse(markdown.contains("## Section:"))
        XCTAssertFalse(markdown.contains("## CTA:"))
        let parsed = try compiler.markdownToSplash(markdown)

        XCTAssertEqual(parsed.sections.map(\.heading), original.sections.map(\.heading))
        XCTAssertEqual(parsed.sections.map(\.subtitle), original.sections.map(\.subtitle))
        XCTAssertEqual(parsed.sections.map(\.bodyParagraphs), original.sections.map(\.bodyParagraphs))
        XCTAssertEqual(parsed.ctas.map(\.name), original.ctas.map(\.name))
        XCTAssertEqual(parsed.ctas.map(\.heading), original.ctas.map(\.heading))
        XCTAssertEqual(parsed.ctas.map(\.subtitle), original.ctas.map(\.subtitle))
        XCTAssertEqual(parsed.ctas.map(\.href), original.ctas.map(\.href))
    }

    func testLegacyFencedJSONStillParses() throws {
        let compiler = HomeMarkdownCompiler()
        let markdown = """
        # Home Canvas

        ## Sections

        ```subtext-section
        {
          "id": "hero",
          "heading": "I'm Tom",
          "subtitle": "Communicator.",
          "bodyParagraphs": ["Hello world"],
          "imagePosition": "left",
          "isHero": true,
          "visual": {
            "type": "photo",
            "photo": { "src": "/me.jpg", "alt": "Me" }
          }
        }
        ```

        ## CTAs

        ```subtext-cta
        {
          "id": "cta-projects",
          "name": "Projects CTA",
          "heading": "Projects",
          "subtitle": "Read work",
          "href": "/projects"
        }
        ```
        """

        let parsed = try compiler.markdownToSplash(markdown)
        XCTAssertEqual(parsed.sections.first?.id, "hero")
        XCTAssertEqual(parsed.sections.first?.heading, "I'm Tom")
        XCTAssertEqual(parsed.ctas.first?.id, "cta-projects")
        XCTAssertEqual(parsed.ctas.first?.href, "/projects")
    }

    func testParseFailsWhenCTAIsMissingLink() {
        let compiler = HomeMarkdownCompiler()
        let markdown = """
        # Home

        ## Section: hero
        ### I'm Tom
        Hello world

        ## CTA: cta-projects
        ### Projects CTA
        Missing link line here
        """

        XCTAssertThrowsError(try compiler.markdownToSplash(markdown)) { error in
            XCTAssertEqual(error as? HomeMarkdownCompiler.ParseError, .missingCTALink(id: "cta-projects"))
        }
    }

    func testParseFailsWhenNoSectionBlocks() {
        let compiler = HomeMarkdownCompiler()
        XCTAssertThrowsError(try compiler.markdownToSplash("# Home")) { error in
            XCTAssertEqual(error as? HomeMarkdownCompiler.ParseError, .missingSectionBlocks)
        }
    }
}
