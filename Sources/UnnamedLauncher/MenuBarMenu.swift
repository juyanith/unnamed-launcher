import AppKit
import SwiftUI
import UnnamedLauncherKit

/// What the menu bar menu and icon show, worked out from the app's state,
/// so the self-test can check it without opening the menu (S-002, S-008, S-009).
struct MenuBarStatus: Equatable {
    enum Icon: Equatable { case ready, off, warning }

    var icon: Icon
    /// The disabled first line, or nil when a section above says more.
    var statusLine: String?
    var missingPermissions: [Permission]
    var needsRelaunch: Bool
    /// Secure Event Input is on, so leaders can't be seen (S-038).
    var keyboardIsSecured: Bool
    /// The first config error, and how many more there are.
    var firstError: String?
    var moreErrors: Int

    init(launcher: Launcher, store: ConfigStore, now: Date = .now) {
        missingPermissions = launcher.missingPermissions
        needsRelaunch = launcher.needsRelaunch
        keyboardIsSecured = launcher.secureInputIsOn && launcher.isEnabled
        firstError = store.errors.first?.message
        moreErrors = max(0, store.errors.count - 1)
        let attention = !missingPermissions.isEmpty || needsRelaunch || firstError != nil || keyboardIsSecured
        icon = !launcher.isEnabled ? .off : attention ? .warning : .ready
        if !launcher.isEnabled {
            statusLine = "Not capturing leaders"
        } else if !missingPermissions.isEmpty || needsRelaunch {
            statusLine = nil
        } else if store.createdStarter, firstError == nil {
            statusLine = "Created config file"
        } else if let loadedAt = store.loadedAt {
            statusLine = "Config loaded at \(loadedAt.formatted(date: .omitted, time: .shortened))"
        } else {
            statusLine = nil
        }
    }

    /// The status item's VoiceOver label, which carries the state.
    var accessibilityLabel: String {
        switch icon {
        case .ready: "Unnamed Launcher"
        case .off: "Unnamed Launcher, off"
        case .warning: !missingPermissions.isEmpty ? "Unnamed Launcher, needs permission"
            : keyboardIsSecured ? "Unnamed Launcher, keyboard is secured" : "Unnamed Launcher, needs attention"
        }
    }
}

/// The menu bar menu. It acts as the app's menu bar while no window is open
/// (DESIGN.md, Command map).
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var launcher = model.launcher
        let status = MenuBarStatus(launcher: launcher, store: model.store)

        if let line = status.statusLine {
            Text(line)
        }
        if !status.missingPermissions.isEmpty {
            Section("Needs Permission") {
                ForEach(status.missingPermissions) { permission in
                    Button("\(permission.rawValue) — Open Settings…") { permission.openSettings() }
                }
                Text("Unnamed Launcher needs both to capture your leader keys.")
            }
        }
        if status.keyboardIsSecured {
            Section("Keyboard Is Secured by Another App") {
                Text("A password field or another app has turned on Secure Input, so leader keys can't be seen until it's turned off.")
            }
        }
        if status.needsRelaunch {
            Button("Relaunch to Finish Setup") { launcher.relaunch() }
        }
        if let error = status.firstError {
            Section("Config Error") {
                Text(error)
                if status.moreErrors > 0 { Text("+\(status.moreErrors) more") }
                Button("Open Config File") { model.store.openFile() }
            }
        }
        Divider()
        Toggle("Enabled", isOn: $launcher.isEnabled)
        Divider()
        Button("Reload Config") { model.store.reload() }
            .keyboardShortcut("r")
        Button("Open Config File") { model.store.openFile() }
        Button("Show Config in Finder") { model.store.showInFinder() }
        Divider()
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
        Button("Quit Unnamed Launcher") {
            launcher.stop()
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// The menu bar icon in its three states (DESIGN-SYSTEM.md, StatusIcon).
struct MenuBarIcon: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let status = MenuBarStatus(launcher: model.launcher, store: model.store)
        Image(nsImage: Self.image(for: status.icon))
            .accessibilityLabel(status.accessibilityLabel)
    }

    /// A template image: dimmed when off, with a badge when something needs attention.
    static func image(for icon: MenuBarStatus.Icon) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let base = NSImage(systemSymbolName: StatusIcon.ready, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return NSImage() }
        let size = NSSize(width: base.size.width + 4, height: base.size.height)
        let image = NSImage(size: size, flipped: false) { rect in
            let alpha = icon == .off ? StatusIcon.offOpacity : 1
            base.draw(in: NSRect(x: 0, y: 0, width: base.size.width, height: base.size.height),
                      from: .zero, operation: .sourceOver, fraction: alpha)
            if icon == .warning {
                // A filled dot in the top trailing corner, punched out of the symbol.
                let d = StatusIcon.badgeDiameter
                let dot = NSRect(x: rect.maxX - d, y: rect.maxY - d, width: d, height: d)
                NSColor.clear.set()
                NSBezierPath(ovalIn: dot.insetBy(dx: -2, dy: -2)).fill(using: .copy)
                NSColor.black.set()
                NSBezierPath(ovalIn: dot).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

private extension NSBezierPath {
    func fill(using operation: NSCompositingOperation) {
        NSGraphicsContext.current?.compositingOperation = operation
        fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
}
