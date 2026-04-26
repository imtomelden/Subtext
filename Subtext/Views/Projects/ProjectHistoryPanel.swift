import SwiftUI

struct ProjectHistoryPanel: View {
    let fileName: String

    @Environment(CMSStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [BackupService.BackupEntry] = []
    @State private var loading = true
    @State private var restoreTarget: BackupService.BackupEntry?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fileName) history")
                        .font(.title3.weight(.semibold))
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
                                    restoreTarget = entry
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
        .alert(item: $restoreTarget) { entry in
            Alert(
                title: Text("Restore from backup?"),
                message: Text("This will overwrite \(fileName). A backup of the current state will be saved first."),
                primaryButton: .destructive(Text("Restore")) {
                    Task {
                        await store.restoreProject(fileName: fileName, from: entry.url)
                        await refresh()
                        dismiss()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        entries = (try? await store.backupService.listBackups(for: fileName)) ?? []
    }
}
