import SwiftUI

struct HomeHistoryPanel: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [BackupService.BackupEntry] = []
    @State private var loading = true
    @State private var diffTarget: BackupService.BackupEntry?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .frame(width: 520, height: 480)
        .task {
            await refresh()
        }
        .sheet(item: $diffTarget) { entry in
            HistoryDiffSheet(
                title: "splash.json — backup vs current",
                backup: entry,
                liveFile: RepoConstants.splashFile
            ) {
                await store.restoreSplash(from: entry.url)
                await refresh()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("splash.json history")
                    .font(.title3.weight(.semibold))
                Text("\(entries.count) backup\(entries.count == 1 ? "" : "s") retained")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    @ViewBuilder
    private var list: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    HistoryRow(entry: entry) {
                        diffTarget = entry
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No backups yet")
                .font(.body.weight(.medium))
            Text("Backups are created on app/window close, and before delete/restore actions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        do {
            entries = try await store.backupService.listBackups(for: "splash.json")
        } catch {
            entries = []
        }
    }
}
