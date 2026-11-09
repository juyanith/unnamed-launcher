import SwiftUI
import UnnamedLauncherKit

/// The Bindings page (S-023 to S-029, S-034): an outline of leaders, menus
/// and bindings in file order, and an editor for the selected row.
struct BindingsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undo
    @State private var confirmDelete: KeySequence?

    private var editor: BindingsEditor { model.editor }

    var body: some View {
        @Bindable var editor = editor
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                IssuesBanner()
                outline
            }
            Divider()
            EntryEditor()
                .frame(width: Layout.editorPaneWidth)
        }
        .navigationTitle("Bindings")
        .toolbar {
            ToolbarItemGroup {
                Button("New Binding", systemImage: "plus") { editor.addBinding(undo: undo) }
                    .help("Add a binding to the selected menu (⌘N)")
                Button("New Menu", systemImage: "folder.badge.plus") { editor.addMenu(undo: undo) }
                    .help("Add a menu, or a leader when nothing is selected (⇧⌘N)")
            }
        }
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let path = confirmDelete { editor.delete(path, undo: undo) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can undo this with ⌘Z.")
        }
    }

    private var confirmTitle: String {
        guard let path = confirmDelete, let entry = editor.draft.entry(path) else { return "" }
        let count = editor.descendantCount(path)
        return "Delete “\(entry.title)” and the \(count) \(count == 1 ? "Entry" : "Entries") Under It?"
    }

    private var outline: some View {
        @Bindable var editor = editor
        return VStack(spacing: 0) {
            OutlineHeader()
            List(selection: $editor.selection) {
                ForEach(editor.draft.children(of: nil), id: \.self) { leader in
                    OutlineRow(path: leader)
                }
                .onMove { editor.move(in: nil, from: $0, to: $1, undo: undo) }
            }
            .listStyle(.inset)
            .onDeleteCommand { requestDelete() }
            .onKeyPress(.space) {
                guard let selection = editor.selection else { return .ignored }
                editor.select(selection, focus: .key)
                return .handled
            }
            .contextMenu(forSelectionType: KeySequence.self) { paths in
                if let path = paths.first { OutlineMenu(path: path, onDelete: { requestDelete(path) }) }
            }
            .overlay {
                if editor.draft.config.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Bindings", systemImage: "keyboard")
                    } description: {
                        Text("Add a leader such as Hyper+Space, then the keys under it.")
                    } actions: {
                        Button("New Menu") { editor.addMenu(undo: undo) }
                    }
                }
            }
        }
    }

    /// Delete asks first only when a menu has entries under it (S-027).
    private func requestDelete(_ path: KeySequence? = nil) {
        guard let path = path ?? editor.selection else { return }
        if editor.descendantCount(path) > 0 { confirmDelete = path } else { editor.delete(path, undo: undo) }
    }
}

/// Column titles over the outline.
private struct OutlineHeader: View {
    var body: some View {
        HStack(spacing: Space.sm) {
            Text("Key").frame(width: Layout.keyColumnWidth, alignment: .leading)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
            Text("Action").frame(width: Layout.actionColumnWidth, alignment: .leading)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.xs)
        .accessibilityHidden(true)
    }
}

/// One row, and its children when it's a menu.
private struct OutlineRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undo
    let path: KeySequence
    @State private var isExpanded = true

    var body: some View {
        let editor = model.editor
        let children = editor.draft.children(of: path)
        if editor.draft.entry(path)?.action == nil && !editor.needsAction.contains(path) {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children, id: \.self) { child in
                    OutlineRow(path: child)
                }
                .onMove { editor.move(in: path, from: $0, to: $1, undo: undo) }
            } label: {
                OutlineCells(path: path)
            }
            .tag(path)
        } else {
            OutlineCells(path: path).tag(path)
        }
    }
}

/// Key, title and action, lined up with the header.
private struct OutlineCells: View {
    @Environment(AppModel.self) private var model
    let path: KeySequence

    var body: some View {
        let document = model.editor.draft
        let entry = document.entry(path)
        let action = entry?.action.flatMap { document.config.actions[$0] }
        HStack(spacing: Space.sm) {
            Text((path.lastStep ?? path.leader).description)
                .font(.system(.body, design: .monospaced))
                .frame(width: Layout.keyColumnWidth - Space.xl, alignment: .leading)
            Text(entry?.title ?? "")
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            Group {
                if let id = entry?.action {
                    Text(id).help(action.map { "\($0.displayName): \(id)" } ?? id)
                } else if model.editor.needsAction.contains(path) {
                    Text("Choose an action").foregroundStyle(Surfaces.warning)
                } else {
                    Text("Menu")
                }
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: Layout.actionColumnWidth, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\((path.lastStep ?? path.leader).description), \(entry?.title ?? ""), \(entry?.action ?? "menu")")
    }
}

/// The right-click menu on a row (S-043 adds the rest).
private struct OutlineMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undo
    let path: KeySequence
    let onDelete: () -> Void

    var body: some View {
        let editor = model.editor
        let isMenu = editor.draft.entry(path)?.action == nil
        if isMenu {
            Button("Add Binding Here") { editor.selection = path; editor.addBinding(undo: undo) }
            Button("Sort Alphabetically") { editor.sort(path, undo: undo) }
        }
        Button("Record Key") { editor.select(path, focus: .key) }
        Divider()
        Button("Delete", role: .destructive, action: onDelete)
    }
}

/// The list of errors above the outline (S-023, S-034). Clicking one selects
/// the row it's about.
private struct IssuesBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let issues = model.editor.issues
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: Space.xs) {
                Label(model.store.errors.isEmpty ? "These changes aren't saved yet" : "The config file has errors. Showing the last valid version.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(Surfaces.warning)
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Button(issue.message) { model.editor.show(issue) }
                        .buttonStyle(.link)
                        .multilineTextAlignment(.leading)
                        .disabled(issue.subject == nil)
                        .help(issue.subject == nil ? "" : "Select the entry this is about")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md)
            .background(Surfaces.warning.opacity(0.12), in: .rect(cornerRadius: Radius.md))
            .padding([.horizontal, .top], Space.md)
        }
    }
}

extension BindingsEditor {
    /// Selects the row an issue is about and focuses the field with the problem (S-034).
    func show(_ issue: ConfigIssue) {
        guard let subject = issue.subject else { return }
        if let path = KeySequence(parsing: subject), draft.index(of: path) != nil {
            let message = issue.message
            let field: Field = message.contains("action") ? .action
                : message.contains("title") ? .title : .key
            select(path, focus: field)
        }
    }
}
