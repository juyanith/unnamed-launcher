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
}

enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, self-test).
    static var isOverridden: Bool {
        ConfigLocation.isOverridden(environment: ProcessInfo.processInfo.environment)
    }
}
