import XCTest
@testable import Subtext

final class BuildServiceTests: XCTestCase {
    func testClassifyKnownDevServerError() {
        let line = "[InvalidContentEntryDataError] invalid schema"
        XCTAssertEqual(
            BuildService.classifyKnownDevServerError(line),
            "Astro content schema validation failed"
        )
    }

    func testClassifyKnownDevServerErrorReturnsNilForUnknownLine() {
        XCTAssertNil(BuildService.classifyKnownDevServerError("random output"))
    }

    func testLegacyBlockScanFindsMediaGalleryAliasOnly() {
        let frontmatter = """
        title: Example
        blocks:
          - type: projectSnapshot
          - type: quote
          - type: mediaGallery
        """

        let hits = LegacyBlockMigration.scanLegacyBlockTypes(in: frontmatter)

        XCTAssertEqual(
            hits,
            [
                .init(index: 2, legacyType: "mediaGallery", canonicalType: "mediaGrid"),
            ]
        )
    }

    func testLegacyMigrationRewritesMediaGridAliasAndEmptyVideoIds() {
        let frontmatter = """
        title: Example
        blocks:
          - type: projectSnapshot
          - type: keyStats
          - type: goalsMetrics
          - type: mediaGallery
          - type: videoShowcase
            source:
              kind: youtube
              videoId: ""
        """

        let migrated = LegacyBlockMigration.migrate(frontmatter: frontmatter)

        XCTAssertTrue(migrated.didChange)
        XCTAssertEqual(migrated.legacyTypeChanges.count, 1)
        XCTAssertEqual(migrated.repairedEmptyVideoIdCount, 1)
        XCTAssertTrue(migrated.content.contains("- type: projectSnapshot"))
        XCTAssertTrue(migrated.content.contains("- type: keyStats"))
        XCTAssertTrue(migrated.content.contains("- type: goalsMetrics"))
        XCTAssertTrue(migrated.content.contains("- type: mediaGrid"))
        XCTAssertFalse(migrated.content.contains("- type: narrative"))
        XCTAssertTrue(migrated.content.contains("videoId: placeholder-video-id"))
    }

    func testLegacyMigrationIsIdempotent() {
        let frontmatter = """
        title: Example
        blocks:
          - type: keyStats
          - type: mediaGallery
        """

        let once = LegacyBlockMigration.migrate(frontmatter: frontmatter)
        let twice = LegacyBlockMigration.migrate(frontmatter: once.content)

        XCTAssertTrue(once.didChange)
        XCTAssertFalse(twice.didChange)
        XCTAssertEqual(twice.content, once.content)
    }

    func testParserCanonicalTypeMapsAliases() {
        XCTAssertEqual(LegacyBlockMigration.parserCanonicalType(for: "statCards"), "keyStats")
        XCTAssertEqual(LegacyBlockMigration.parserCanonicalType(for: "mediaGrid"), "mediaGallery")
        XCTAssertEqual(LegacyBlockMigration.parserCanonicalType(for: "quote"), "quote")
    }

    func testSynthesiseLayoutInjectsDefaultOrderFromLegacyFrontmatter() throws {
        let mdx = """
        ---
        title: "T"
        slug: t
        description: "D"
        date: 2026-01-01
        ownership: work
        tags: [a, b]
        headerImage: /x.png
        hero:
          eyebrow: E
        challenge: C
        videoMeta:
          runtime: 5 min
        externalUrl: https://example.com
        blocks:
          - type: videoShowcase
            variant: cinema
            title: "Vid"
            source:
              kind: youtube
              videoId: abc
        ---

        Body
        """
        let doc = try MDXParser.parse(mdx, fileName: "t.mdx")
        let kinds = doc.frontmatter.blocks.map(\.kind)
        XCTAssertEqual(
            kinds,
            [
                .pageHero, .headerImage, .body, .videoShowcase,
                .caseStudy, .videoDetails, .externalLink, .tagList, .relatedProjects,
            ]
        )
    }

    func testSynthesiseLayoutSkippedWhenLayoutBlockPresent() throws {
        let mdx = """
        ---
        title: "T"
        slug: t
        description: "D"
        date: 2026-01-01
        ownership: work
        tags: []
        blocks:
          - type: body
          - type: quote
            quote: "Hi"
        ---

        Hi
        """
        let doc = try MDXParser.parse(mdx, fileName: "t.mdx")
        XCTAssertEqual(doc.frontmatter.blocks.map(\.kind), [.body, .quote])
    }

    func testStopWhenNoTrackedProcessCompletes() async {
        let service = BuildService()
        await service.stop()
        let pid = await service.currentPID()
        XCTAssertNil(pid)
    }
}
