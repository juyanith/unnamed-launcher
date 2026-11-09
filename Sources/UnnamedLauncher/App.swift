import AppKit
import SwiftUI

// UnnamedLauncher
//   UnnamedLauncher                      the app (menu bar only, no Dock icon)
//   APP_STORE=<file> UnnamedLauncher     use another config file (tests, experiments)
//   APP_SNAPSHOT=<dir> UnnamedLauncher   save a PNG of every settings page in light and dark mode, then quit
//   UnnamedLauncher --selftest           run the self-test against a /tmp config and quit with 0 or 1 (tools/selftest.sh)
//   APP_GRID=1 UnnamedLauncher           draw the grid and the layout probes over the window

@main
struct UnnamedLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    /// Snapshots and the self-test need the window open at launch. Normal
    /// launches stay in the menu bar until you choose Settings…
    private static var opensWindowAtLaunch: Bool {
        SelfTest.requested || !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty
    }

    var body: some Scene {
        MenuBarExtra("Unnamed Launcher", systemImage: "command") {
            MenuBarMenu()
        }

        Window("Unnamed Launcher Settings", id: WindowID.settings) {
            ContentView()
                .environment(model)
                .themed()
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
    }
}

enum WindowID {
    static let settings = "settings"
}

/// The menu bar menu. Stories S-002, S-008 and S-009 fill it in.
struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            openWindow(id: WindowID.settings)
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Unnamed Launcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu bar app: no Dock icon, no main menu until a window is open.
        NSApp.setActivationPolicy(.accessory)
    }

    /// Closing the settings window leaves the app running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
