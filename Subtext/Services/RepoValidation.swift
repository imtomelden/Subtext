import Foundation

struct RepoValidationReport: Sendable {
    var blockingIssues: [String]
    var warnings: [String]

    var isValid: Bool { blockingIssues.isEmpty }
}

enum RepoValidationError: LocalizedError {
    case invalidSelection(String)

    var errorDescription: String? {
        switch self {
        case .invalidSelection(let message):
            return message
        }
    }
}

enum RepoValidator {
    static func validateRepo(at root: URL) -> RepoValidationReport {
        let fm = FileManager.default
        var blocking: [String] = []
        var warnings: [String] = []

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
            return RepoValidationReport(
                blockingIssues: ["Selected folder does not exist or is not a directory."],
                warnings: []
            )
        }

        let packageJSON = root.appending(path: "package.json", directoryHint: .notDirectory)
        if !fm.fileExists(atPath: packageJSON.path(percentEncoded: false)) {
            blocking.append("Missing package.json at repo root.")
        } else if !packageJSONContainsDevScript(packageJSON) {
            blocking.append("package.json must define scripts.dev (used by `npm run dev`).")
        }

        let contentDir = root
            .appending(path: "src", directoryHint: .isDirectory)
            .appending(path: "content", directoryHint: .isDirectory)
        if !isExistingDirectory(contentDir) {
            blocking.append("Missing required folder: src/content")
        }

        let splash = contentDir.appending(path: "splash.json", directoryHint: .notDirectory)
        if !fm.fileExists(atPath: splash.path(percentEncoded: false)) {
            blocking.append("Missing required file: src/content/splash.json")
        }

        let site = contentDir.appending(path: "site.json", directoryHint: .notDirectory)
        if !fm.fileExists(atPath: site.path(percentEncoded: false)) {
            blocking.append("Missing required file: src/content/site.json")
        }

        let projects = contentDir.appending(path: "projects", directoryHint: .isDirectory)
        if !isExistingDirectory(projects) {
            blocking.append("Missing required folder: src/content/projects")
        }

        if !hasAstroMarker(root) {
            warnings.append("Could not confirm Astro marker (astro.config.* or astro dependency).")
        }

        return RepoValidationReport(blockingIssues: blocking, warnings: warnings)
    }

    static func assertValidRepoSelection(at root: URL) throws {
        let report = validateRepo(at: root)
        guard report.isValid else {
            throw RepoValidationError.invalidSelection(report.blockingIssues.joined(separator: "\n"))
        }
    }

    private static func packageJSONContainsDevScript(_ packageJSON: URL) -> Bool {
        guard
            let data = try? Data(contentsOf: packageJSON),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let scripts = json["scripts"] as? [String: Any],
            scripts["dev"] != nil
        else {
            return false
        }
        return true
    }

    private static func hasAstroMarker(_ root: URL) -> Bool {
        let fm = FileManager.default
        let astroConfigCandidates = ["astro.config.mjs", "astro.config.js", "astro.config.ts"]
        if astroConfigCandidates.contains(where: { fm.fileExists(atPath: root.appending(path: $0, directoryHint: .notDirectory).path(percentEncoded: false)) }) {
            return true
        }

        let packageJSON = root.appending(path: "package.json", directoryHint: .notDirectory)
        guard
            let data = try? Data(contentsOf: packageJSON),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }

        let dependencies = json["dependencies"] as? [String: Any] ?? [:]
        let devDependencies = json["devDependencies"] as? [String: Any] ?? [:]
        return dependencies["astro"] != nil || devDependencies["astro"] != nil
    }

    private static func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false),
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }
}
