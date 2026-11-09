import SwiftUI

/// The Bindings window: a sidebar of pages and the selected page.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            switch model.sidebar ?? .bindings {
            case .bindings: BindingsPage()
            case .actions: ActionsPage()
            case .contexts: ContextsPage()
            }
        }
        .noInitialFocus()
        .onChange(of: model.store.revision) { model.editor.reloadFromStore() }
        .task {
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }

    private var sidebar: some View {
        @Bindable var model = model
        return List(SidebarItem.allCases, selection: $model.sidebar) { page in
            Label(page.title, systemImage: page.symbol)
                .tag(page)
        }
        .navigationSplitViewColumnWidth(min: Layout.sidebarMin, ideal: Layout.sidebarIdeal)
    }
}

