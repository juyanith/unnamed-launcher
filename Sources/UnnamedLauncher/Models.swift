import AppKit
import UnnamedLauncherKit

/// The Bindings window's sidebar pages. Snapshot mode walks through every case.
enum SidebarItem: String, CaseIterable, Identifiable {
    case bindings, actions, contexts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bindings: "Bindings"
        case .actions: "Actions"
        case .contexts: "Contexts"
        }
    }

    var symbol: String {
        switch self {
        case .bindings: "keyboard"
        case .actions: "bolt"
        case .contexts: "macwindow.on.rectangle"
        }
    }

    /// What the empty page says until its story is built.
    var emptyMessage: String {
        switch self {
        case .bindings: "Leaders, menus and bindings from the config file appear here."
        case .actions: "Actions that bindings run appear here."
        case .contexts: "Sets of apps that Choose by App checks appear here."
        }
    }
}

/// App-wide state that menus and views share.
@Observable
final class AppModel {
    var sidebar: SidebarItem? = .bindings

    /// How many of the app's windows are open. While any is, the app is a
    /// regular app with a main menu (Edit > Undo, Window); otherwise it lives
    /// only in the menu bar (DESIGN.md, Archetype).
    var openWindows = 0 {
        didSet {
            NSApp.setActivationPolicy(openWindows > 0 ? .regular : .accessory)
        }
    }

    /// The config file. Tests and snapshots point APP_STORE at a file in /tmp.
    let configURL = ConfigLocation.url(environment: ProcessInfo.processInfo.environment,
                                       home: URL.homeDirectory)
    let store: ConfigStore
    let launcher: Launcher
    /// The draft the Bindings window and Settings edit.
    let editor: BindingsEditor
    /// The selected action and context on their pages.
    var actionSelection: String?
    var contextSelection: String?

    /// The one model, for the app delegate.
    private(set) static weak var current: AppModel?

    init() {
        store = ConfigStore(url: configURL)
        launcher = Launcher(store: store)
        // Snapshots and the self-test never capture the real keyboard.
        let isSnapshot = !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty
        // Snapshots show the sample config, so every page has content.
        launcher.start(captureKeys: !SelfTest.requested && !isSnapshot, seed: isSnapshot ? SeedData.fixtureJSON : nil)
        editor = BindingsEditor(store: store)
        editor.onRecordingChange = { [launcher] in launcher.setRecording($0) }
        Self.current = self
    }

    /// Shows an action on the Actions page.
    func showAction(_ id: String) {
        actionSelection = id
        sidebar = .actions
    }
}

enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, self-test).
    static var isOverridden: Bool {
        ConfigLocation.isOverridden(environment: ProcessInfo.processInfo.environment)
    }
}
