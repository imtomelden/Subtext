import Foundation

/// Temporary NDJSON logger for debug sessions (writes to workspace `.cursor/` file).
enum AgentDebugLog {
    private static let path = "/Users/tomblagden/Documents/Projects/Subtext/.cursor/debug-aa263a.log"
    private static let sessionId = "aa263a"

    static func append(
        location: String,
        message: String,
        hypothesisId: String,
        runId: String = "pre-fix",
        data: [String: String] = [:]
    ) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "timestamp": timestamp,
            "data": data,
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: json, encoding: .utf8) else { return }
        line += "\n"
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
