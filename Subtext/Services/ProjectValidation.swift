import Foundation

struct ProjectValidationIssue: Equatable, Sendable {
    let field: String
    let message: String
}

enum ProjectValidator {
    static func validate(_ document: ProjectDocument) -> [ProjectValidationIssue] {
        validate(frontmatter: document.frontmatter)
    }

    static func validate(frontmatter: ProjectFrontmatter) -> [ProjectValidationIssue] {
        var issues: [ProjectValidationIssue] = []

        func isBlank(_ value: String) -> Bool {
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if isBlank(frontmatter.title) {
            issues.append(.init(field: "title", message: "Title is required."))
        }
        if isBlank(frontmatter.slug) {
            issues.append(.init(field: "slug", message: "Slug is required."))
        }
        if isBlank(frontmatter.description) {
            issues.append(.init(field: "description", message: "Description is required."))
        }
        if isBlank(frontmatter.date) {
            issues.append(.init(field: "date", message: "Date is required."))
        } else if ISO8601Date.parse(frontmatter.date) == nil {
            issues.append(.init(field: "date", message: "Date must use YYYY-MM-DD."))
        }

        issues.append(contentsOf: validateRequiredBlockFields(frontmatter.blocks))
        return issues
    }

    private static func validateRequiredBlockFields(_ blocks: [ProjectBlock]) -> [ProjectValidationIssue] {
        var issues: [ProjectValidationIssue] = []

        for (index, block) in blocks.enumerated() {
            switch block {
            case .videoShowcase(let video):
                switch video.source {
                case .youtube(let videoId):
                    if videoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(.init(
                            field: "blocks[\(index)].source.videoId",
                            message: "YouTube videoId is required for Video Showcase blocks."
                        ))
                    }
                case .file(let src, _, _, _, _):
                    if src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(.init(
                            field: "blocks[\(index)].source.src",
                            message: "File source path is required for Video Showcase blocks."
                        ))
                    }
                case .vimeo(let videoId):
                    if videoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(.init(
                            field: "blocks[\(index)].source.videoId",
                            message: "Vimeo videoId is required for Video Showcase blocks."
                        ))
                    }
                }
            case .cta(let cta):
                if cta.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(
                        field: "blocks[\(index)].title",
                        message: "CTA block title is required."
                    ))
                }
            case .headerImage(let img):
                if img.src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(
                        field: "blocks[\(index)].src",
                        message: "Header image block needs an image path."
                    ))
                }
            case .externalLink(let ext):
                if ext.href.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(
                        field: "blocks[\(index)].href",
                        message: "External link block needs a URL."
                    ))
                }
            case .quote(let quote):
                if quote.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(
                        field: "blocks[\(index)].quote",
                        message: "Quote block text is required."
                    ))
                }
            case .preface(let preface):
                if preface.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(
                        field: "blocks[\(index)].text",
                        message: "Preface text is required."
                    ))
                }
            default:
                break
            }
        }

        return issues
    }
}
