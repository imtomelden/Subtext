import Foundation

/// Root of `site.json`. The live schema is tiny (`blogPublic` only) — kept in
/// its own type so adding future flags is a single-file change.
struct SiteSettings: Equatable, Codable, Sendable {
    var blogPublic: Bool

    static let `default` = SiteSettings(blogPublic: true)
}
