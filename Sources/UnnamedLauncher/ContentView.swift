import SwiftUI

/// The Bindings window: a sidebar of pages and the selected page.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            BindingsPage(page: model.sidebar ?? .bindings)
        }
        .noInitialFocus()
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

/// One page of the Bindings window. Each is an empty state until its story
/// is built (Bindings S-023, Actions S-030, Contexts S-031).
struct BindingsPage: View {
    let page: SidebarItem

    var body: some View {
        ContentUnavailableView(
            "No \(page.title) Yet",
            systemImage: page.symbol,
            description: Text(page.emptyMessage)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(page.title)
    }
}
