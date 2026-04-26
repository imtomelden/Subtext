import Foundation

/// Minimal YAML decoder — just enough to parse the subset emitted by
/// `gray-matter` on the website side. Supports:
///
///   * `key: value` mappings
///   * `key:` followed by indented children
///   * block sequences (`- item` / `- key: value`)
///   * flow sequences (`[a, b, c]`)
///   * scalars: strings (plain, "double-quoted", 'single-quoted'),
///     integers, booleans (`true|false`), and `null` / `~`
///
/// Multiline scalars (`|`, `>`) are represented as plain strings joined by
/// a single newline — the current website content doesn't use them.
enum YAMLNode: Equatable {
    case null
    case scalar(String)
    case sequence([YAMLNode])
    case mapping([String: YAMLNode])

    var stringValue: String? {
        switch self {
        case .scalar(let s): s
        case .null: nil
        default: nil
        }
    }

    var boolValue: Bool {
        switch self {
        case .scalar(let s): ["true", "yes", "on", "1"].contains(s.lowercased())
        default: false
        }
    }

    var sequenceValue: [YAMLNode] {
        switch self {
        case .sequence(let xs): xs
        default: []
        }
    }
}

enum YAMLDecoder {
    static func decode(_ text: String, fileName: String) throws -> YAMLNode {
        var lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        // Drop trailing blanks.
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeLast()
        }
        if lines.isEmpty { return .mapping([:]) }

        var parser = Parser(lines: lines, fileName: fileName)
        return try parser.parseMapping(indent: 0)
    }

    // MARK: - Recursive-descent parser

    private struct Parser {
        var lines: [String]
        var index: Int = 0
        let fileName: String

        mutating func parseMapping(indent: Int) throws -> YAMLNode {
            var map: [String: YAMLNode] = [:]
            while index < lines.count {
                let line = lines[index]
                let lineIndent = leadingSpaces(line)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    index += 1
                    continue
                }
                if lineIndent < indent { break }
                if lineIndent > indent { break }
                if trimmed.hasPrefix("- ") || trimmed == "-" { break }

                // `key: value` or `key:`
                guard let colon = firstColonOutsideQuotes(in: trimmed) else {
                    throw MDXParser.ParseError.invalidYAML(
                        fileName: fileName,
                        reason: "Expected 'key:' at line \(index + 1): \"\(trimmed)\""
                    )
                }
                let key = String(trimmed.prefix(colon)).trimmingCharacters(in: .whitespaces)
                let after = trimmed.suffix(trimmed.count - colon - 1)
                    .trimmingCharacters(in: .whitespaces)

                index += 1

                if after.isEmpty {
                    let childIndent = nextContentIndent(after: indent)
                    if childIndent > indent {
                        // nested mapping OR sequence
                        if isSequenceStart(at: childIndent) {
                            map[key] = try parseSequence(indent: childIndent)
                        } else {
                            map[key] = try parseMapping(indent: childIndent)
                        }
                    } else {
                        map[key] = .null
                    }
                } else {
                    map[key] = try parseScalarOrFlow(after)
                }
            }
            return .mapping(map)
        }

        mutating func parseSequence(indent: Int) throws -> YAMLNode {
            var out: [YAMLNode] = []
            while index < lines.count {
                let line = lines[index]
                let lineIndent = leadingSpaces(line)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    index += 1
                    continue
                }
                if lineIndent < indent { break }
                if lineIndent > indent { break }
                guard trimmed.hasPrefix("- ") || trimmed == "-" else { break }

                let afterDash = String(trimmed.dropFirst(trimmed == "-" ? 1 : 2))
                    .trimmingCharacters(in: .whitespaces)

                if trimmed == "-" {
                    // The item's content is on subsequent lines at a deeper indent.
                    index += 1
                    let childIndent = nextContentIndent(after: indent)
                    if childIndent > indent {
                        if isSequenceStart(at: childIndent) {
                            out.append(try parseSequence(indent: childIndent))
                        } else {
                            out.append(try parseMapping(indent: childIndent))
                        }
                    } else {
                        out.append(.null)
                    }
                } else if let colon = firstColonOutsideQuotes(in: afterDash) {
                    // Inline `- key: value` starts a mapping item.
                    let key = String(afterDash.prefix(colon)).trimmingCharacters(in: .whitespaces)
                    let val = afterDash.suffix(afterDash.count - colon - 1).trimmingCharacters(in: .whitespaces)

                    // The first key starts at `indent + 2` typically; children use the same column.
                    let keyIndent = indent + 2
                    var map: [String: YAMLNode] = [:]

                    if val.isEmpty {
                        index += 1
                        let childIndent = nextContentIndent(after: keyIndent)
                        if childIndent > keyIndent {
                            if isSequenceStart(at: childIndent) {
                                map[key] = try parseSequence(indent: childIndent)
                            } else {
                                map[key] = try parseMapping(indent: childIndent)
                            }
                        } else {
                            map[key] = .null
                        }
                    } else {
                        map[key] = try parseScalarOrFlow(val)
                        index += 1
                    }

                    // Remaining keys of the same item are indented at `keyIndent`.
                    if index < lines.count {
                        let rest = try parseMapping(indent: keyIndent)
                        if case .mapping(let extra) = rest {
                            for (k, v) in extra { map[k] = v }
                        }
                    }
                    out.append(.mapping(map))
                } else {
                    // `- scalar`
                    out.append(try parseScalarOrFlow(afterDash))
                    index += 1
                }
            }
            return .sequence(out)
        }

        // MARK: - Helpers

        func leadingSpaces(_ line: String) -> Int {
            var n = 0
            for c in line {
                if c == " " { n += 1 }
                else if c == "\t" { n += 2 }
                else { break }
            }
            return n
        }

        func isSequenceStart(at indent: Int) -> Bool {
            guard index < lines.count else { return false }
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return (trimmed.hasPrefix("- ") || trimmed == "-")
                && leadingSpaces(line) == indent
        }

        /// Look ahead for the next non-empty/non-comment line's indent.
        func nextContentIndent(after baseIndent: Int) -> Int {
            var i = index
            while i < lines.count {
                let line = lines[i]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    i += 1; continue
                }
                return leadingSpaces(line)
            }
            return baseIndent
        }

        func firstColonOutsideQuotes(in s: String) -> Int? {
            var inDouble = false
            var inSingle = false
            var escape = false
            var i = 0
            for c in s {
                defer { i += 1 }
                if escape { escape = false; continue }
                if c == "\\" { escape = true; continue }
                if c == "\"" && !inSingle { inDouble.toggle(); continue }
                if c == "'" && !inDouble { inSingle.toggle(); continue }
                if !inDouble && !inSingle && c == ":" {
                    // colon inside `key: value` must be followed by space or end.
                    let nextIdx = s.index(s.startIndex, offsetBy: i + 1, limitedBy: s.endIndex)
                    if nextIdx == s.endIndex { return i }
                    if let next = nextIdx, s[next] == " " || s[next] == "\t" { return i }
                    return i
                }
            }
            return nil
        }

        func parseScalarOrFlow(_ raw: String) throws -> YAMLNode {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let inner = String(trimmed.dropFirst().dropLast())
                if inner.trimmingCharacters(in: .whitespaces).isEmpty {
                    return .sequence([])
                }
                let parts = splitFlowList(inner)
                return .sequence(parts.map { .scalar(unquote($0)) })
            }
            if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
                let inner = String(trimmed.dropFirst().dropLast())
                var map: [String: YAMLNode] = [:]
                for pair in splitFlowList(inner) {
                    if let colon = firstColonOutsideQuotes(in: pair) {
                        let k = String(pair.prefix(colon)).trimmingCharacters(in: .whitespaces)
                        let v = pair.suffix(pair.count - colon - 1).trimmingCharacters(in: .whitespaces)
                        map[unquote(k)] = .scalar(unquote(String(v)))
                    }
                }
                return .mapping(map)
            }
            if trimmed.isEmpty || trimmed == "~" || trimmed.lowercased() == "null" {
                return .null
            }
            return .scalar(unquote(trimmed))
        }

        func splitFlowList(_ s: String) -> [String] {
            var out: [String] = []
            var current = ""
            var depth = 0
            var inDouble = false
            var inSingle = false
            var escape = false
            for c in s {
                if escape { current.append(c); escape = false; continue }
                if c == "\\" { current.append(c); escape = true; continue }
                if c == "\"" && !inSingle { inDouble.toggle(); current.append(c); continue }
                if c == "'" && !inDouble { inSingle.toggle(); current.append(c); continue }
                if !inDouble && !inSingle {
                    if c == "[" || c == "{" { depth += 1 }
                    if c == "]" || c == "}" { depth -= 1 }
                    if c == "," && depth == 0 {
                        out.append(current.trimmingCharacters(in: .whitespaces))
                        current = ""
                        continue
                    }
                }
                current.append(c)
            }
            if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(current.trimmingCharacters(in: .whitespaces))
            }
            return out
        }

        func unquote(_ s: String) -> String {
            let t = s.trimmingCharacters(in: .whitespaces)
            if t.count >= 2 {
                if t.hasPrefix("\"") && t.hasSuffix("\"") {
                    return String(t.dropFirst().dropLast())
                        .replacingOccurrences(of: "\\\"", with: "\"")
                        .replacingOccurrences(of: "\\n", with: "\n")
                }
                if t.hasPrefix("'") && t.hasSuffix("'") {
                    return String(t.dropFirst().dropLast())
                        .replacingOccurrences(of: "''", with: "'")
                }
            }
            return t
        }
    }
}
