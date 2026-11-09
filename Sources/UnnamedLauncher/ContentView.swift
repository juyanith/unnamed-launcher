import SwiftUI

/// The settings window: a sidebar of pages and the selected page.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            SettingsPage(page: model.sidebar ?? .bindings)
        }
        .noInitialFocus()
        .task {
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model)
        }
    }

    private var sidebar: some View {
        @Bindable var model = model
        return List(SidebarItem.allCases, selection: $model.sidebar) { page in
            Label(page.title, systemImage: page.symbol)
                .tag(page)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}

/// One settings page. Each page is an empty state until its story is built
/// (Bindings S-023, Actions S-030, Contexts S-031, General S-032).
struct SettingsPage: View {
    let page: SidebarItem

    var body: some View {
        ContentUnavailableView(
            page.emptyTitle,
            systemImage: page.symbol,
            description: Text(page.emptyMessage)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(page.title)
    }
}
