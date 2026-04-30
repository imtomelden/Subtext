import SwiftUI

/// Top-level Projects container. Shows a persistent two-pane layout:
/// project list on the left, editor on the right.
struct ProjectsRootView: View {
    @Environment(CMSStore.self) private var store
    @State private var activeSheet: ActiveSheet?

    private let listWidth: CGFloat = 320

    var body: some View {
        @Bindable var store = store

        HStack(spacing: 0) {
            ProjectsListView()
                .frame(width: listWidth)

            Divider()

            if let fileName = store.selectedProjectFileName,
               let binding = store.binding(forProject: fileName) {
                ProjectEditorView(
                    document: binding,
                    onAddBlock: { activeSheet = .blockPicker(fileName: fileName) },
                    onShowHistory: { activeSheet = .history(fileName: fileName) }
                )
                .slidingPanel(isPresented: store.editingBlockID != nil) {
                    if let blockID = store.editingBlockID,
                       let blockBinding = blockBinding(for: blockID, in: binding) {
                        BlockEditorPanel(block: blockBinding) {
                            store.editingBlockID = nil
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .subtextNewItem)) { _ in
                    activeSheet = .blockPicker(fileName: fileName)
                }
                .id("editor.\(fileName)")
            } else {
                noSelectionPlaceholder
            }
        }
        .animation(.easeOut(duration: 0.20), value: store.selectedProjectFileName)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .blockPicker(let fileName):
                if let binding = store.binding(forProject: fileName) {
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
                } else {
                    Text("Project unavailable")
                        .padding(24)
                }
            case .history(let fileName):
                ProjectHistoryPanel(fileName: fileName)
            }
        }
    }

    @ViewBuilder
    private var noSelectionPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Select a project to start editing")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private enum ActiveSheet: Identifiable {
        case blockPicker(fileName: String)
        case history(fileName: String)

        var id: String {
            switch self {
            case .blockPicker(let fileName):
                "blockPicker.\(fileName)"
            case .history(let fileName):
                "history.\(fileName)"
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
