import SwiftUI
import UnnamedLauncherKit

/// The editor beside the outline: the selected row's key, title and action
/// (S-024 to S-026).
struct EntryEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undo
    @FocusState private var focus: BindingsEditor.Field?
    @State private var title = ""

    private var editor: BindingsEditor { model.editor }

    var body: some View {
        if let path = editor.selection, let entry = editor.draft.entry(path) {
            Form {
                Section {
                    LabeledContent("Key") { KeyRecorder(path: path) }
                    TextField("Title", text: $title)
                        .focused($focus, equals: .title)
                        .onSubmit { editor.setTitle(path, title, undo: undo) }
                        .onChange(of: focus) { old, _ in
                            if old == .title { editor.setTitle(path, title, undo: undo) }
                        }
                } footer: {
                    Text(path.isLeader ? "A leader is a chord that opens its menu from anywhere."
                                       : "A single key, pressed after the keys above it.")
                }
                if entry.action != nil || editor.needsAction.contains(path) {
                    Section {
                        actionPicker(path, entry)
                    } footer: {
                        Text("What this binding does. Edit actions on the Actions page.")
                    }
                } else {
                    Section {
                        LabeledContent("Kind", value: path.isLeader ? "Leader" : "Menu")
                        LabeledContent("Keys under it", value: "\(editor.draft.children(of: path).count)")
                    }
                }
            }
            .formStyle(.grouped)
            .onAppear { title = entry.title }
            .onChange(of: path) { _, _ in title = editor.draft.entry(path)?.title ?? "" }
            .onChange(of: editor.focus, initial: true) { _, field in
                if field == .title || field == .action { focus = field }
            }
        } else {
            ContentUnavailableView("No Selection", systemImage: "keyboard",
                                   description: Text("Select a binding or menu to edit it."))
        }
    }

    private func actionPicker(_ path: KeySequence, _ entry: Config.Entry) -> some View {
        let document = editor.draft
        let ids = document.actionOrder.filter { document.config.actions[$0] != nil }
        return Picker("Action", selection: Binding(
            get: { entry.action ?? "" },
            set: { id in
                if id == BindingsEditor.newActionTag {
                    let created = editor.newAction(for: path, undo: undo)
                    model.showAction(created)
                } else if !id.isEmpty {
                    editor.setAction(path, id, undo: undo)
                }
            })) {
            if entry.action == nil { Text("Choose an Action").tag("") }
            ForEach(ids, id: \.self) { id in
                Text("\(id) (\(document.config.actions[id]!.displayName))").tag(id)
            }
            Divider()
            Text("New Action…").tag(BindingsEditor.newActionTag)
        }
        .focused($focus, equals: .action)
    }
}

extension BindingsEditor {
    /// The popup tag for "New Action…", which no action id can be.
    static let newActionTag = "\u{0}new"

    /// The action popup's choices: every action, then New Action… (S-026).
    var actionChoices: [String] {
        draft.actionOrder.filter { draft.config.actions[$0] != nil } + [Self.newActionTag]
    }
}
