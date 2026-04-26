import Foundation
import Observation

/// In-memory ring-buffer of app events — errors, warnings, and notable
/// successes. Populated from `CMSStore.showError` and kin; read by the
/// Settings > Event Log sheet for post-mortem debugging.
///
/// Deliberately non-persistent: crash logs live in Console.app, and
/// durable reports belong in a future Sparkle/feedback integration. This
/// buffer just surfaces the session's history so the user can screenshot
/// an issue before it scrolls off the toast.
@Observable
@MainActor
final class EventLog {
    struct Entry: Identifiable, Sendable, Equatable {
        enum Severity: String, Sendable, CaseIterable {
            case info, warning, error

            var iconName: String {
                switch self {
                case .info: "info.circle"
                case .warning: "exclamationmark.triangle"
                case .error: "exclamationmark.octagon"
                }
            }
        }

        let id: UUID = UUID()
        let timestamp: Date
        let severity: Severity
        let category: String
        let message: String
    }

    private(set) var entries: [Entry] = []
    private let cap: Int

    init(cap: Int = 200) {
        self.cap = cap
    }

    func append(_ severity: Entry.Severity, category: String, message: String) {
        entries.append(Entry(
            timestamp: Date(),
            severity: severity,
            category: category,
            message: message
        ))
        if entries.count > cap {
            entries.removeFirst(entries.count - cap)
        }
    }

    func clear() {
        entries.removeAll()
    }

    var errorCount: Int { entries.filter { $0.severity == .error }.count }
}
