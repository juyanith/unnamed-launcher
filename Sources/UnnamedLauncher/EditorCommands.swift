import SwiftUI
import UnnamedLauncherKit

/// The Bindings window's menu bar commands (DESIGN.md, Command map). Each
/// one is also a toolbar button, a context menu item or a key in the outline.
struct EditorCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            switch model.sidebar ?? .bindings {
            case .bindings:
                Button("New Binding") { model.editor.addBinding(undo: undoManager) }
                    .keyboardShortcut("n")
                Button("New Menu") { model.editor.addMenu(undo: undoManager) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            case .actions, .contexts:
                EmptyView()
            }
            Divider()
            Button("Reload Config") { model.store.reload() }
                .keyboardShortcut("r")
            Button("Open Config File") { model.store.openFile() }
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Record Key") {
                if let path = model.editor.selection { model.editor.select(path, focus: .key) }
            }
            .disabled(model.sidebar != .bindings || model.editor.selection == nil)
            Button("Sort Alphabetically") {
                model.editor.sort(model.editor.targetMenu, undo: undoManager)
            }
            .disabled(model.sidebar != .bindings || model.editor.targetMenu == nil)
        }
        CommandGroup(before: .sidebar) {
            ForEach(Array(SidebarItem.allCases.enumerated()), id: \.element) { index, page in
                Button(page.title) { model.sidebar = page }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
            }
            Divider()
        }
    }

    /// The key window's undo manager, so menu commands undo with ⌘Z.
    private var undoManager: UndoManager? { NSApp.keyWindow?.undoManager }
}
