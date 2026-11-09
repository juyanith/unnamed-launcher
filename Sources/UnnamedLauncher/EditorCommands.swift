import SwiftUI
import UnnamedLauncherKit

/// The Bindings window's menu bar commands (DESIGN.md, Command map). Each
/// one is also a toolbar button, a context menu item or a key in the outline.
struct EditorCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            if (model.sidebar ?? .bindings) == .bindings {
                ForEach(OutlineCommand.menuBarFile) { item($0) }
            }
            Divider()
            Button("Reload Config") { model.store.reload() }
                .keyboardShortcut("r")
            Button("Open Config File") { model.store.openFile() }
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            ForEach(OutlineCommand.menuBarEdit) { item($0) }
        }
        CommandGroup(before: .sidebar) {
            ForEach(Array(SidebarItem.allCases.enumerated()), id: \.element) { index, page in
                Button(page.title) { model.sidebar = page }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
            }
            Divider()
        }
    }

    /// One outline command as a menu bar item, with its shortcut.
    @ViewBuilder
    private func item(_ command: OutlineCommand) -> some View {
        let button = Button(command.title) {
            command.perform(on: nil, editor: model.editor, undo: undoManager) { path in
                model.editor.delete(path, undo: undoManager)
            }
        }
        .disabled(model.sidebar != .bindings || (command != .newBinding && command != .newMenu && model.editor.selection == nil))
        if let shortcut = command.shortcut { button.keyboardShortcut(shortcut) } else { button }
    }

    /// The key window's undo manager, so menu commands undo with ⌘Z.
    private var undoManager: UndoManager? { NSApp.keyWindow?.undoManager }
}
