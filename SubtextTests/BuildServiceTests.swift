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

    func testLegacyBlockScanFindsLegacyTypesWithBlockIndexes() {
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
                .init(index: 0, legacyType: "projectSnapshot", canonicalType: "narrative"),
                .init(index: 2, legacyType: "mediaGallery", canonicalType: "mediaGrid")
            ]
        )
    }

    func testLegacyMigrationRewritesLegacyTypesAndEmptyVideoIds() {
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
        XCTAssertEqual(migrated.legacyTypeChanges.count, 4)
        XCTAssertEqual(migrated.repairedEmptyVideoIdCount, 1)
        XCTAssertTrue(migrated.content.contains("- type: narrative"))
        XCTAssertTrue(migrated.content.contains("- type: statCards"))
        XCTAssertTrue(migrated.content.contains("- type: mediaGrid"))
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

    func testStopWhenNoTrackedProcessCompletes() async {
        let service = BuildService()
        await service.stop()
        let pid = await service.currentPID()
        XCTAssertNil(pid)
    }
}
