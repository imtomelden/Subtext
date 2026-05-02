import SwiftUI

/// Top-level Projects container. Shows a persistent two-pane layout:
/// project list on the left, editor on the right.
struct ProjectsRootView: View {
    @Environment(CMSStore.self) private var store
    @Environment(\.narrowLayout) private var narrowLayout
    @State private var activeSheet: ActiveSheet?

    private var listWidth: CGFloat {
        if narrowLayout.isVeryNarrow { return 232 }
        if narrowLayout.isNarrow { return 260 }
        return 280
    }

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
                .onReceive(NotificationCenter.default.publisher(for: .subtextNewItem)) { _ in
                    activeSheet = .blockPicker(fileName: fileName)
                }
                .id("editor.\(fileName)")
            } else {
                noSelectionPlaceholder
            }
        }
        .animation(.easeOut(duration: 0.20), value: store.selectedProjectFileName)
        .onChange(of: store.pendingBlockKind) { _, kind in
            guard let kind, let fileName = store.selectedProjectFileName,
                  let binding = store.binding(forProject: fileName) else {
                store.pendingBlockKind = nil
                return
            }
            let block = ProjectBlock.empty(of: kind)
            binding.wrappedValue.frontmatter.blocks.append(block)
            store.editingBlockID = block.id
            store.pendingBlockKind = nil
        }
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

}
