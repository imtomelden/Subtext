import SwiftUI

struct ProjectHistoryPanel: View {
    let fileName: String

    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [BackupService.BackupEntry] = []
    @State private var loading = true
    @State private var diffTarget: BackupService.BackupEntry?

    private var liveURL: URL {
        RepoConstants.projectsDirectory
            .appending(path: fileName, directoryHint: .notDirectory)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fileName) history")
                        .font(SubtextUI.Typography.sectionTitle)
                    Text("\(entries.count) backup\(entries.count == 1 ? "" : "s") retained")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 32)).foregroundStyle(.secondary)
                        Text("No backups yet")
                            .font(.body.weight(.medium))
                        Text("Backups appear here after your first close or a delete/restore action.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
            }
        }
        .frame(width: 520, height: 480)
        .task { await refresh() }
        .sheet(item: $diffTarget) { entry in
            HistoryDiffSheet(
                title: "\(fileName) — backup vs current",
                backup: entry,
                liveFile: liveURL
            ) {
                await store.restoreProject(fileName: fileName, from: entry.url)
                await refresh()
                dismiss()
            }
        }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        entries = (try? await store.backupService.listBackups(for: fileName)) ?? []
    }
}
