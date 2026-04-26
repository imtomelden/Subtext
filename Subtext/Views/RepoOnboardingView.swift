import AppKit
import SwiftUI

/// Shown on first launch (or whenever the stored security-scoped bookmark
/// is missing / stale). Routing the user through `NSOpenPanel` here means
/// Powerbox grants explicit consent for the chosen folder, so Subtext can
/// read `~/Documents/Projects/Website` on subsequent launches without the
/// macOS TCC folder-access prompt firing again.
struct RepoOnboardingView: View {
    @Environment(CMSStore.self) private var store
    @State private var picking = false
    @State private var showDetails = false
    @State private var selectionError: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(Color.subtextAccent)

            VStack(spacing: 8) {
                Text("Welcome to Subtext")
                    .font(.largeTitle.weight(.semibold))

                Text("Pick your Astro website repo to get started.")
                    .font(SubtextUI.Typography.body)
                    .foregroundStyle(.secondary)
            }

            Button {
                chooseFolder()
            } label: {
                Label("Choose Website folder…", systemImage: "folder.badge.plus")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(Color.subtextAccent)
            .disabled(picking)
            .keyboardShortcut(.defaultAction)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showDetails.toggle()
                }
            } label: {
                Text(showDetails ? "Hide details" : "What this includes")
                    .font(SubtextUI.Typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)

            if showDetails {
                Text("Subtext reads and writes splash.json, site.json, and MDX projects inside this folder. Picking it once grants access so macOS won't ask again each launch.")
                    .font(SubtextUI.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)
        }
        .padding(SubtextUI.Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Folder validation failed", isPresented: Binding(
            get: { selectionError != nil },
            set: { if !$0 { selectionError = nil } }
        ), presenting: selectionError) { _ in
            Button("OK", role: .cancel) { selectionError = nil }
        } message: { message in
            Text(message)
        }
    }

    private func chooseFolder() {
        picking = true
        defer { picking = false }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use folder"
        panel.message = "Pick the Astro website repo containing src/content."
        // Suggest the legacy / default location as a starting point but
        // don't stat it — leave the user to confirm via the panel.
        panel.directoryURL = RepoConstants.defaultRepoRoot.deletingLastPathComponent()

        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        do {
            try RepoValidator.assertValidRepoSelection(at: chosen)
        } catch {
            selectionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }
        RepoConstants.setRepoRoot(chosen)
        Task { await store.loadAll() }
    }
}
