import Foundation

/// Root of `site.json`. The live schema is tiny — kept in its own type so
/// adding future flags is a single-file change.
struct SiteSettings: Equatable, Codable, Sendable {
    var blogPublic: Bool
    /// Optional shell command run at repo root before `npm run build` during publish.
    /// Non-zero exit aborts the pipeline; stdout/stderr are appended to the publish log.
    var preBuildScript: String?
    var microblog: MicroblogSettings?

    static let `default` = SiteSettings(blogPublic: true, preBuildScript: nil, microblog: nil)
}

/// Micro.blog CMS settings stored in `site.json`. The API token is kept in
/// Keychain — only the non-secret page URL lives here.
struct MicroblogSettings: Equatable, Codable, Sendable {
    /// Full URL of the Micro.blog page storing splash.json content, e.g.
    /// "https://micro.blog/imtomelden/blagsite-home"
    var pageURL: String
    var enabled: Bool
}
