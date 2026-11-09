import AppKit
import SwiftUI
import OSLog
import Synchronization
import UnnamedLauncherKit

/// Self-test checks for M5 and M6: the tap, Secure Input, the schema, polish.
extension SelfTest {
    /// M5: recovering the tap, Secure Event Input, the JSON Schema.
    static func systemChecks(_ model: AppModel) {
        // S-037: a "tap disabled" event turns the tap back on, passes, and is logged.
        let handled = Mutex(0)
        let context = TapContext { _ in handled.withLock { $0 += 1 }; return true }
        var passes = true
        for type in [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput] {
            passes = passes && !context.handle(RawKeyEvent(type: type, keyCode: 0, isRepeat: false, flags: [], isFromLauncher: false))
        }
        check("S-037 a disabled-tap event is handled by the tap, not the engine", passes && handled.withLock { $0 } == 0)
        check("S-037 turning the tap back on is logged", logContains("turning it back on"))

        // S-038: Secure Event Input shows in the menu and badges the icon.
        let launcher = model.launcher
        launcher.setSecureInputForTesting(true)
        let secured = MenuBarStatus(launcher: launcher, store: model.store)
        check("S-038 Secure Input shows in the menu with a warning icon", secured.keyboardIsSecured && secured.icon == .warning)
        // A missing permission is the bigger problem, so it wins the label.
        check("S-038 the VoiceOver label says the keyboard is secured", secured.accessibilityLabel
              == (secured.missingPermissions.isEmpty ? "Unnamed Launcher, keyboard is secured" : "Unnamed Launcher, needs permission"))
        launcher.setSecureInputForTesting(false)
        check("S-038 the warning goes when Secure Input is off", !MenuBarStatus(launcher: launcher, store: model.store).keyboardIsSecured)

        // S-039: the schema is written next to the config, and the starter points at it.
        let schemaURL = model.store.url.deletingLastPathComponent().appending(path: ConfigSchema.fileName)
        check("S-039 config.schema.json is written next to the config",
              (try? Data(contentsOf: schemaURL)) == Data(ConfigSchema.json.utf8), schemaURL.path)
    }

    /// M6: the welcome window, icons, context menus, keyboard.
    static func polishChecks(_ model: AppModel) {
        // S-040: the welcome window shows until both permissions and one sequence are done.
        check("S-040 the welcome window shows until setup is done",
              !WelcomeStatus(accessibility: true, inputMonitoring: true, ranSequence: false).isComplete
              && !WelcomeStatus(accessibility: true, inputMonitoring: false, ranSequence: true).isComplete
              && WelcomeStatus(accessibility: true, inputMonitoring: true, ranSequence: true).isComplete)

        // S-043: every right-click item is in the menu bar, with the same name.
        let contextItems = Set(OutlineCommand.forRow(isMenu: true) + OutlineCommand.forRow(isMenu: false))
        check("S-043 every context menu item is also in the menu bar", contextItems.isSubset(of: Set(OutlineCommand.inMenuBar)))
        check("S-043 Duplicate has ⌘D in the menu bar", OutlineCommand.duplicate.shortcut == KeyboardShortcut("d"))

        // S-044: VoiceOver reads each row as "key, title, action", and Return edits the title.
        let editor = model.editor
        if let binding = editor.draft.paths.compactMap({ $0 }).first(where: { editor.draft.entry($0)?.action != nil }),
           let menu = editor.draft.children(of: nil).first {
            let entry = editor.draft.entry(binding)!
            check("S-044 VoiceOver reads a binding as key, title, action",
                  editor.accessibilityLabel(for: binding) == "\(binding.lastStep!.description), \(entry.title), \(entry.action!)")
            check("S-044 VoiceOver reads a menu as key, title, menu",
                  editor.accessibilityLabel(for: menu).hasSuffix(", menu"))
            editor.select(binding, focus: .title)
            check("S-044 Return puts the cursor in the title field", editor.focus == .title && editor.recording == nil)
            editor.focus = nil
        }
    }
}
