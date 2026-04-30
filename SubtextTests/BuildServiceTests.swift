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

    func testKeyStatsValuePrefixParsesAndSerialises() throws {
        let mdx = """
        ---
        title: "T"
        slug: t
        description: "D"
        date: 2026-01-01
        ownership: work
        tags: []
        blocks:
          - type: keyStats
            title: "Key stats"
            items:
              - label: "Budget"
                valuePrefix: "$"
                value: "1.2"
                unit: "m"
                context: "Approximate"
                lastUpdated: "2026-04-30"
        ---

        Body
        """

        let parsed = try MDXParser.parse(mdx, fileName: "t.mdx")
        guard let keyStatsBlock = parsed.frontmatter.blocks.first(where: {
            if case .keyStats = $0 { return true }
            return false
        }) else {
            XCTFail("Expected keyStats block")
            return
        }
        guard case .keyStats(let block) = keyStatsBlock else {
            XCTFail("Expected keyStats block")
            return
        }
        XCTAssertEqual(block.items.first?.valuePrefix, "$")
        XCTAssertEqual(block.items.first?.value, "1.2")

        let serialised = MDXSerialiser.serialise(parsed)
        XCTAssertTrue(serialised.contains("valuePrefix: \"$\""))
        XCTAssertTrue(serialised.contains("value: \"$1.2\""))
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

    func testFileServiceWriteProjectUpdatesSubsequentRead() async throws {
        let root = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "example.mdx", directoryHint: .notDirectory)
        let service = FileService()

        try writeText(
            """
            ---
            title: "Initial title"
            slug: initial-title
            description: "D"
            date: 2026-01-01
            ownership: work
            tags: []
            ---

            Initial body.
            """,
            to: url
        )

        let first = try await service.readProject(at: url)
        XCTAssertEqual(first.frontmatter.title, "Initial title")
        XCTAssertEqual(first.body.trimmingCharacters(in: .whitespacesAndNewlines), "Initial body.")

        var updated = first
        updated.frontmatter.title = "Updated title"
        updated.frontmatter.slug = "updated-title"
        updated.frontmatter.date = "2026-01-02"
        updated.body = "Updated body.\n"
        try await service.writeProject(updated, to: url)

        let second = try await service.readProject(at: url)
        XCTAssertEqual(second.frontmatter.title, "Updated title")
        XCTAssertEqual(second.body.trimmingCharacters(in: .whitespacesAndNewlines), "Updated body.")
    }

    func testFileServiceDeleteProjectRemovesFile() async throws {
        let root = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "to-delete.mdx", directoryHint: .notDirectory)
        let service = FileService()

        try writeText(
            """
            ---
            title: "Delete me"
            slug: delete-me
            description: "D"
            date: 2026-01-01
            ownership: work
            tags: []
            ---

            Body.
            """,
            to: url
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        try await service.deleteProject(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    func testFileServiceReadProjectRepairsMissingSlugAndOwnership() async throws {
        let root = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "legacy-project.mdx", directoryHint: .notDirectory)
        let service = FileService()

        try writeText(
            """
            ---
            title: "Legacy"
            description: "D"
            date: 2026-01-01
            tags: []
            ---

            Legacy body.
            """,
            to: url
        )

        let read = try await service.readProject(at: url)
        XCTAssertEqual(read.frontmatter.slug, "legacy-project")
        XCTAssertEqual(read.frontmatter.ownership, .work)

        let reread = try await service.readProject(at: url)
        XCTAssertEqual(reread.frontmatter.slug, "legacy-project")
        XCTAssertEqual(reread.frontmatter.ownership, .work)
    }

    func testFileServiceReadProjectRefreshesCacheAfterExternalChange() async throws {
        let root = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var url = root.appending(path: "cache-refresh.mdx", directoryHint: .notDirectory)
        let service = FileService()

        try writeText(
            """
            ---
            title: "Version one"
            slug: cache-refresh
            description: "D"
            date: 2026-01-01
            ownership: work
            tags: []
            ---

            Body one.
            """,
            to: url
        )

        let first = try await service.readProject(at: url)
        XCTAssertEqual(first.frontmatter.title, "Version one")

        try writeText(
            """
            ---
            title: "Version two"
            slug: cache-refresh
            description: "D"
            date: 2026-01-01
            ownership: work
            tags: []
            ---

            Body two.
            """,
            to: url
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(5)],
            ofItemAtPath: url.path(percentEncoded: false)
        )
        url.removeAllCachedResourceValues()

        let second = try await service.readProject(at: url)
        XCTAssertEqual(second.frontmatter.title, "Version two")
        XCTAssertEqual(second.body.trimmingCharacters(in: .whitespacesAndNewlines), "Body two.")
    }

    private func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeText(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

@MainActor
final class CMSStorePipelineTests: XCTestCase {
    func testReloadProjectMissingFileRemovesSelectionAndCompletes() async throws {
        let repoRoot = makeTempRepo()
        defer { tearDownTempRepo(repoRoot) }
        RepoConstants.setRepoRoot(repoRoot)
        defer { RepoConstants.resetToDefaultRepoRoot() }

        let fileName = "reload-delete.mdx"
        var projectURL = repoRoot
            .appending(path: "src/content/projects", directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
        try writeText(validProjectMDX(fileName: fileName, title: "Original"), to: projectURL)

        let store = CMSStore()
        await store.reloadProject(at: projectURL)
        store.selectedProjectFileName = fileName
        XCTAssertEqual(store.projects.count, 1)

        try FileManager.default.removeItem(at: projectURL)
        await store.reloadProject(at: projectURL)

        XCTAssertTrue(store.projects.isEmpty)
        XCTAssertNil(store.selectedProjectFileName)
        XCTAssertEqual(store.projectReloadPipelineState, .complete(total: 1))
    }

    func testReloadProjectExistingFileUpdatesStoreAndResetsDirty() async throws {
        let repoRoot = makeTempRepo()
        defer { tearDownTempRepo(repoRoot) }
        RepoConstants.setRepoRoot(repoRoot)
        defer { RepoConstants.resetToDefaultRepoRoot() }

        let fileName = "reload-update.mdx"
        var projectURL = repoRoot
            .appending(path: "src/content/projects", directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
        try writeText(validProjectMDX(fileName: fileName, title: "First"), to: projectURL)

        let store = CMSStore()
        await store.reloadProject(at: projectURL)
        XCTAssertEqual(store.projects.first?.frontmatter.title, "First")

        try writeText(validProjectMDX(fileName: fileName, title: "Second"), to: projectURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(120)],
            ofItemAtPath: projectURL.path(percentEncoded: false)
        )
        projectURL.removeAllCachedResourceValues()

        await store.reloadProject(at: projectURL)

        XCTAssertEqual(store.projects.first?.frontmatter.title, "Second")
        XCTAssertFalse(store.isProjectDirty(fileName))
        XCTAssertEqual(store.projectReloadPipelineState, .complete(total: 1))
    }

    func testSaveProjectValidationFailureSetsErrorStateAndTelemetry() async throws {
        let repoRoot = makeTempRepo()
        defer { tearDownTempRepo(repoRoot) }
        RepoConstants.setRepoRoot(repoRoot)
        defer { RepoConstants.resetToDefaultRepoRoot() }

        let fileName = "save-invalid.mdx"
        let projectURL = repoRoot
            .appending(path: "src/content/projects", directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
        try writeText(validProjectMDX(fileName: fileName, title: "Valid"), to: projectURL)

        let store = CMSStore()
        var doc = try MDXParser.parse(validProjectMDX(fileName: fileName, title: "Valid"), fileName: fileName)
        doc.frontmatter.slug = ""
        store.projects = [doc]
        await store.saveProject(fileName)

        guard case .error(let target, let message) = store.savePipelineState else {
            XCTFail("Expected save pipeline error state")
            return
        }
        XCTAssertEqual(target, fileName)
        XCTAssertFalse(message.isEmpty)
        XCTAssertGreaterThan(store.pipelineTelemetry.saveFailures, 0)
    }

    // MARK: - Helpers

    private func makeTempRepo() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let content = root.appending(path: "src/content", directoryHint: .isDirectory)
        let projects = content.appending(path: "projects", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        return root
    }

    private func tearDownTempRepo(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }

    private func writeText(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func validProjectMDX(fileName: String, title: String) -> String {
        let slug = fileName.replacingOccurrences(of: ".mdx", with: "")
        return """
        ---
        title: "\(title)"
        slug: \(slug)
        description: "Desc"
        date: 2026-01-01
        ownership: work
        tags: []
        ---

        Body
        """
    }
}
