import SwiftUI

struct ProjectSnapshotBlockEditor: View {
    @Binding var block: ProjectSnapshotBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow("Project title") {
                TextField("Project title", text: $block.projectTitle)
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow("Summary") {
                TextField("One-line summary", text: $block.summary, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }
            FieldRow("Status") {
                Picker("Status", selection: $block.status) {
                    ForEach(ProjectSnapshotBlock.Status.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            FieldRow("Owner/team") {
                TextField("Owner or delivery team", text: $block.ownerTeam)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(alignment: .top, spacing: 12) {
                FieldRow("Start date") {
                    DateField(value: $block.timelineStart)
                }
                FieldRow("Target completion") {
                    DateField(value: $block.timelineTargetCompletion)
                }
            }
            FieldRow("Budget headline") {
                TextField("Optional, e.g. £1.2m approved budget", text: Binding(
                    get: { block.budgetHeadline ?? "" },
                    set: { block.budgetHeadline = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
