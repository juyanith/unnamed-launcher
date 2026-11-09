import AppKit
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
}
