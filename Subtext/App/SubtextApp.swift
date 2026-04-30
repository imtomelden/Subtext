import SwiftUI

@main
struct SubtextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = CMSStore()
    @State private var devServer = DevServerController()
    @State private var git = GitController()
    @State private var publish = PublishController()

    var body: some Scene {
        // `WindowGroup` (instead of single-instance `Window`) so the user
        // can open multiple editor windows side-by-side via File > New
        // Window. The `store`, `devServer`, `git`, and `publish` controllers
        // are App-level `@State` so all windows share them — true per-window
        // repo isolation would require lifting these into a `@SceneStorage`-
        // driven Scene type (or using opaque Scene state). That's the path
        // the plan outlines for "multi-window per repo"; leaving the seam
        // here keeps the door open without forking the data layer today.
        WindowGroup("Subtext", id: "subtext-main") {
            ContentView()
                .environment(store)
                .environment(devServer)
                .environment(git)
                .environment(publish)
                .frame(
                    minWidth: RepoConstants.minimumWindowSize.width,
                    minHeight: RepoConstants.minimumWindowSize.height
                )
                .task { await store.loadAll() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands { subtextCommands }

        Window("Live preview", id: "subtext-preview") {
            LivePreviewView()
                .environment(store)
                .environment(devServer)
                .frame(minWidth: 700, minHeight: 800)
        }
        .windowResizability(.contentMinSize)

        Window("Dev server", id: "subtext-devserver") {
            DevServerWindow()
                .environment(devServer)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContent()
                .environment(store)
                .environment(devServer)
                .environment(git)
                .environment(publish)
        } label: {
            Image(systemName: "text.append")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(menuBarExtraTint)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarExtraTint: Color {
        switch devServer.phase {
        case .running:
            Color.subtextAccent
        case .failed:
            .red
        case .preflighting, .starting, .stopping, .restarting:
            Color.subtextWarning
        case .stopped:
            .secondary
        }
    }

    @CommandsBuilder
    private var subtextCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                NotificationCenter.default.post(name: .subtextNewItem, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                NotificationCenter.default.post(name: .subtextSave, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Discard Changes") {
                NotificationCenter.default.post(name: .subtextDiscard, object: nil)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show Live Preview") {
                NotificationCenter.default.post(name: .subtextOpenPreview, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button("Toggle Focus Mode") {
                NotificationCenter.default.post(name: .subtextToggleFocusMode, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
        }
        CommandGroup(after: .textEditing) {
            Button("Bold in Project Body") {
                NotificationCenter.default.post(name: .subtextProjectInsertBold, object: nil)
            }
            .keyboardShortcut("b", modifiers: .command)

            Button("Italic in Project Body") {
                NotificationCenter.default.post(name: .subtextProjectInsertItalic, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)

            Button("Heading in Project Body") {
                NotificationCenter.default.post(name: .subtextProjectInsertHeading, object: nil)
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Link in Project Body") {
                NotificationCenter.default.post(name: .subtextProjectInsertLink, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .option])

            Button("Info Chip in Project Body") {
                NotificationCenter.default.post(name: .subtextProjectInsertInfoChip, object: nil)
            }

            Button("Cycle Project Editor Mode") {
                NotificationCenter.default.post(name: .subtextProjectTogglePreviewMode, object: nil)
            }
            .keyboardShortcut("\\", modifiers: [.command, .option])

            Divider()

            Button("Go to…") {
                NotificationCenter.default.post(
                    name: .subtextOpenPalette,
                    object: CommandPalette.Mode.navigate
                )
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Find in Content…") {
                NotificationCenter.default.post(
                    name: .subtextOpenPalette,
                    object: CommandPalette.Mode.search
                )
            }
            .keyboardShortcut("f", modifiers: .command)

            Divider()

            Button("Move Selection Up") {
                NotificationCenter.default.post(name: .subtextMoveItemUp, object: nil)
            }
            .keyboardShortcut(.upArrow, modifiers: [.control, .option])

            Button("Move Selection Down") {
                NotificationCenter.default.post(name: .subtextMoveItemDown, object: nil)
            }
            .keyboardShortcut(.downArrow, modifiers: [.control, .option])
        }
        CommandMenu("Git") {
            Button("Commit & Push…") {
                NotificationCenter.default.post(name: .subtextOpenGitPanel, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button("Refresh Status") {
                NotificationCenter.default.post(name: .subtextRefreshGit, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts…") {
                NotificationCenter.default.post(name: .subtextOpenKeyboardShortcuts, object: nil)
            }

            Button("Event Log…") {
                NotificationCenter.default.post(name: .subtextOpenEventLog, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let subtextSave = Notification.Name("SubtextSave")
    static let subtextDiscard = Notification.Name("SubtextDiscard")
    static let subtextNewItem = Notification.Name("SubtextNewItem")
    static let subtextOpenGitPanel = Notification.Name("SubtextOpenGitPanel")
    static let subtextRefreshGit = Notification.Name("SubtextRefreshGit")
    static let subtextOpenPreview = Notification.Name("SubtextOpenPreview")
    static let subtextOpenPalette = Notification.Name("SubtextOpenPalette")
    static let subtextMoveItemUp = Notification.Name("SubtextMoveItemUp")
    static let subtextMoveItemDown = Notification.Name("SubtextMoveItemDown")
    static let subtextToggleFocusMode = Notification.Name("SubtextToggleFocusMode")
    static let subtextOpenKeyboardShortcuts = Notification.Name("SubtextOpenKeyboardShortcuts")
    static let subtextOpenEventLog = Notification.Name("SubtextOpenEventLog")
    static let subtextProjectInsertBold = Notification.Name("SubtextProjectInsertBold")
    static let subtextProjectInsertItalic = Notification.Name("SubtextProjectInsertItalic")
    static let subtextProjectInsertHeading = Notification.Name("SubtextProjectInsertHeading")
    static let subtextProjectInsertLink = Notification.Name("SubtextProjectInsertLink")
    static let subtextProjectInsertInfoChip = Notification.Name("SubtextProjectInsertInfoChip")
    static let subtextProjectTogglePreviewMode = Notification.Name("SubtextProjectTogglePreviewMode")
    static let subtextAppWillTerminate = Notification.Name("SubtextAppWillTerminate")
}
