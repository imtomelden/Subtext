import Foundation

/// Root of `site.json`. The live schema is tiny — kept in its own type so
/// adding future flags is a single-file change.
struct SiteSettings: Equatable, Codable, Sendable {
    var blogPublic: Bool
    /// Optional shell command run at repo root before `npm run build` during publish.
    /// Non-zero exit aborts the pipeline; stdout/stderr are appended to the publish log.
    var preBuildScript: String?

    static let `default` = SiteSettings(blogPublic: true, preBuildScript: nil)
}
