import SwiftUI

/// Popover that lists local branches, filters by search, and checks out the chosen one.
struct BranchSwitcher: View {
    @Environment(GitController.self) private var git
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var branchField: String = ""
    @State private var isCreatingBranch = false
    @FocusState private var searchFocused: Bool
    @FocusState private var branchNameFocused: Bool

    private var filteredBranches: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return git.availableBranches }
        return git.availableBranches.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Switch branch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            TextField("Filter branches", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()

            if git.availableBranches.isEmpty {
                Text("No branches found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            } else {
                newBranchHeader
                Divider()
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(filteredBranches, id: \.self) { branch in
                            branchRow(branch)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 220)
            }

            if git.activity == .checkingOut {
                Divider()
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Checking out…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 280)
        .onAppear {
            git.loadBranches()
            searchFocused = true
        }
    }

    @ViewBuilder
    private var newBranchHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isCreatingBranch {
                HStack(spacing: 6) {
                    TextField("branch-name", text: $branchField)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout.monospaced())
                        .focused($branchNameFocused)
                        .onSubmit(createBranch)
                    Button("Create") {
                        createBranch()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.subtextAccent)
                    .disabled(branchField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || git.isBusy)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                Button("Cancel") {
                    isCreatingBranch = false
                    branchField = ""
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            } else {
                Button {
                    isCreatingBranch = true
                    branchField = ""
                    branchNameFocused = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.subtextAccent)
                        Text("New branch…")
                            .font(.callout.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(git.isBusy)
            }
        }
    }

    private func createBranch() {
        let name = branchField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        git.createBranch(name: name)
        isCreatingBranch = false
        branchField = ""
        dismiss()
    }

    @ViewBuilder
    private func branchRow(_ branch: String) -> some View {
        let isCurrent = branch == git.status.branch
        Button {
            if !isCurrent {
                git.checkout(to: branch)
            }
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isCurrent ? "checkmark" : "arrow.triangle.branch")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isCurrent ? Color.subtextAccent : .secondary)
                    .frame(width: 14)

                Text(branch)
                    .font(.callout.monospaced())
                    .foregroundStyle(isCurrent ? Color.subtextAccent : Tokens.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isCurrent ? Color.subtextAccent.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(git.isBusy && !isCurrent)
    }
}
