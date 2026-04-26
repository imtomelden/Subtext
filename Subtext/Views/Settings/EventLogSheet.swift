import AppKit
import SwiftUI

/// Post-mortem viewer for the session's event log. Shows every error,
/// warning, and notable success routed through `CMSStore.showToast` /
/// `showError`, in newest-first order.
///
/// "Copy all" dumps the entire buffer to the pasteboard as TSV so bugs can
/// be reported without re-running the failing action.
struct EventLogSheet: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 620, height: 480)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Event log").font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                copyAll()
            } label: {
                Label("Copy all", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(store.eventLog.entries.isEmpty)

            Button(role: .destructive) {
                store.eventLog.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(store.eventLog.entries.isEmpty)

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var subtitle: String {
        let total = store.eventLog.entries.count
        let errors = store.eventLog.errorCount
        if total == 0 { return "No events yet this session." }
        if errors == 0 { return "\(total) event\(total == 1 ? "" : "s") this session." }
        return "\(total) event\(total == 1 ? "" : "s") — \(errors) error\(errors == 1 ? "" : "s")."
    }

    @ViewBuilder
    private var content: some View {
        if store.eventLog.entries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.subtextAccent)
                Text("Nothing to report.")
                    .font(.callout)
                Text("Errors and successes show up here as they happen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.eventLog.entries.reversed()) { entry in
                    EventRow(entry: entry)
                }
            }
            .listStyle(.inset)
        }
    }

    private func copyAll() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let tsv = store.eventLog.entries.map { entry in
            [
                fmt.string(from: entry.timestamp),
                entry.severity.rawValue,
                entry.category,
                entry.message.replacingOccurrences(of: "\t", with: " "),
            ].joined(separator: "\t")
        }.joined(separator: "\n")

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(tsv, forType: .string)
    }
}

private struct EventRow: View {
    let entry: EventLog.Entry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.severity.iconName)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.callout)
                    .textSelection(.enabled)

                HStack(spacing: 6) {
                    Text(Self.timeFormatter.string(from: entry.timestamp))
                    Text("·")
                    Text(entry.category)
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var tint: Color {
        switch entry.severity {
        case .info: .secondary
        case .warning: Color.subtextWarning
        case .error: .red
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
