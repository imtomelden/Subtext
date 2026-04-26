import SwiftUI

/// Top-level Projects container. Switches between the list and the full
/// editor depending on `CMSStore.selectedProjectFileName`.
struct ProjectsRootView: View {
    @Environment(CMSStore.self) private var store
    @State private var showBlockPicker = false
    @State private var showHistory = false

    var body: some View {
        @Bindable var store = store

        Group {
            if let fileName = store.selectedProjectFileName,
               let binding = store.binding(forProject: fileName) {
                ProjectEditorView(
                    document: binding,
                    onBack: { store.selectedProjectFileName = nil },
                    onAddBlock: { showBlockPicker = true },
                    onShowHistory: { showHistory = true }
                )
                .slidingPanel(isPresented: store.editingBlockID != nil) {
                    if let blockID = store.editingBlockID,
                       let blockBinding = blockBinding(for: blockID, in: binding) {
                        BlockEditorPanel(block: blockBinding) {
                            store.editingBlockID = nil
                        }
                    }
                }
                .sheet(isPresented: $showBlockPicker) {
                    BlockPicker(
                        title: "Add block",
                        items: ProjectBlock.Kind.allCases.map {
                            PickerItem(
                                id: $0.rawValue,
                                kind: $0,
                                displayName: $0.displayName,
                                systemImage: $0.systemImage
                            )
                        }
                    ) { kind in
                        let block = ProjectBlock.empty(of: kind)
                        binding.wrappedValue.frontmatter.blocks.append(block)
                        store.editingBlockID = block.id
                    }
                }
                .sheet(isPresented: $showHistory) {
                    ProjectHistoryPanel(fileName: fileName)
                }
                .onReceive(NotificationCenter.default.publisher(for: .subtextNewItem)) { _ in
                    showBlockPicker = true
                }
            } else {
                ProjectsListView()
            }
        }
    }

    private func blockBinding(
        for id: UUID,
        in document: Binding<ProjectDocument>
    ) -> Binding<ProjectBlock>? {
        guard let idx = document.wrappedValue.frontmatter.blocks.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { document.wrappedValue.frontmatter.blocks[idx] },
            set: { document.wrappedValue.frontmatter.blocks[idx] = $0 }
        )
    }
}
