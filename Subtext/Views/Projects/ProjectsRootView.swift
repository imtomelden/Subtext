import SwiftUI

/// Top-level Projects container. Switches between the list and the full
/// editor depending on `CMSStore.selectedProjectFileName`.
struct ProjectsRootView: View {
    @Environment(CMSStore.self) private var store
    @State private var activeSheet: ActiveSheet?
    @State private var navigationTransitionStart: ContinuousClock.Instant?
    @State private var navigationSurface: NavigationSurface = .list
    @State private var navigationDirection: NavigationDirection = .toEditor
    @StateObject private var transitionQueue = CoalescedTransitionQueue<NavigationSurface>()

    var body: some View {
        @Bindable var store = store

        ZStack {
            switch navigationSurface {
            case .editor(let fileName):
                if let binding = store.binding(forProject: fileName) {
                    ProjectEditorView(
                        document: binding,
                        onBack: { store.selectedProjectFileName = nil },
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
                    .transition(editorTransition)
                    .id("editor.\(fileName)")
                } else {
                    ProjectsListView()
                        .transition(listTransition)
                        .onAppear {
                            store.selectedProjectFileName = nil
                        }
                }
            case .list:
                ProjectsListView()
                    .transition(listTransition)
                    .id("list")
            }
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
        .onAppear {
            navigationSurface = surface(for: store.selectedProjectFileName)
        }
        .onChange(of: store.selectedProjectFileName) { oldValue, newValue in
            guard oldValue != newValue else { return }
            transitionSurface(to: surface(for: newValue), oldValue: oldValue, newValue: newValue)
        }
        .onDisappear {
            transitionQueue.reset()
        }
    }

    private var editorTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: navigationDirection == .toEditor ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: navigationDirection == .toEditor ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var listTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: navigationDirection == .toEditor ? .leading : .trailing).combined(with: .opacity),
            removal: .move(edge: navigationDirection == .toEditor ? .trailing : .leading).combined(with: .opacity)
        )
    }

    private func surface(for fileName: String?) -> NavigationSurface {
        if let fileName { return .editor(fileName: fileName) }
        return .list
    }

    private func transitionSurface(to target: NavigationSurface, oldValue: String?, newValue: String?) {
        navigationDirection = target == .list ? .toList : .toEditor
        let animateAsSwap = navigationSurface.isEditor && target.isEditor
        let duration = animateAsSwap ? UXMotion.editorSwapDuration : UXMotion.navigationDuration
        transitionQueue.run(
            to: target,
            duration: duration,
            current: { navigationSurface }
        ) { next in
            withAnimation(UXMotion.easeInOut(duration: duration)) {
                navigationSurface = next
            }
        }

        let started = ContinuousClock().now
        navigationTransitionStart = started
        Task { @MainActor in
            await Task.yield()
            let direction = if oldValue == nil, newValue != nil {
                "list_to_editor"
            } else if oldValue != nil, newValue == nil {
                "editor_to_list"
            } else {
                "editor_to_editor"
            }
            store.recordUXMetric("projects.navigation.transition", started: started, metadata: direction)
            if navigationTransitionStart == started {
                navigationTransitionStart = nil
            }
        }
    }

    private enum NavigationDirection {
        case toEditor
        case toList
    }

    private enum NavigationSurface: Equatable {
        case list
        case editor(fileName: String)

        var isEditor: Bool {
            if case .editor = self { return true }
            return false
        }

        var fileName: String? {
            if case .editor(let fileName) = self { return fileName }
            return nil
        }
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
