import AppKit
import SwiftUI

// UnnamedLauncher
//   UnnamedLauncher                      the app (menu bar only until a window opens)
//   APP_STORE=<file> UnnamedLauncher     use another config file (tests, experiments)
//   APP_SNAPSHOT=<dir> UnnamedLauncher   save a PNG of every Bindings page and Settings in light and dark mode, then quit
//   UnnamedLauncher --selftest           run the self-test against a /tmp config and quit with 0 or 1 (tools/selftest.sh)
//   APP_GRID=1 UnnamedLauncher           draw the grid and the layout probes over the window

@main
struct UnnamedLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    /// Snapshots and the self-test need the window open at launch. Normal
    /// launches stay in the menu bar until you choose Edit Bindings…
    private static var opensWindowAtLaunch: Bool {
        SelfTest.requested || !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty
    }

    var body: some Scene {
        MenuBarExtra("Unnamed Launcher", systemImage: "command") {
            MenuBarMenu()
        }

        // The main window: your bindings, actions and contexts. Its title
        // follows the page (DESIGN.md, Information architecture).
        Window("Bindings", id: WindowID.bindings) {
            ContentView()
                .environment(model)
                .themed()
                .countsAsOpenWindow(model)
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 680, minHeight: 440)
        }
        .defaultSize(width: 900, height: 600)
        .defaultLaunchBehavior(Self.opensWindowAtLaunch ? .presented : .suppressed)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
                .countsAsOpenWindow(model)
        }
        .windowResizability(.contentSize)
    }
}

enum WindowID {
    static let bindings = "bindings"
}

/// The menu bar menu. It acts as the app's menu bar while no window is open.
/// Stories S-002, S-008 and S-009 add status, Enabled, Reload Config and
/// Open Config File (DESIGN.md, Command map).
struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Edit Bindings…") {
            openWindow(id: WindowID.bindings)
            NSApp.activate()
        }
        .keyboardShortcut("b")
        Button("Settings…") {
            openSettings()
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Unnamed Launcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

extension View {
    /// Counts this window as open, so the app shows a main menu while it is.
    func countsAsOpenWindow(_ model: AppModel) -> some View {
        onAppear { model.openWindows += 1 }
            .onDisappear { model.openWindows -= 1 }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu bar app: no Dock icon and no main menu until a window opens.
        if NSApp.windows.allSatisfy({ !$0.isVisible }) { NSApp.setActivationPolicy(.accessory) }
    }

    /// Closing the last window leaves the app running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
