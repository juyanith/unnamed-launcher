import AppKit
import UnnamedLauncherKit

/// Self-test for agents: runs the app's real functions against a test config,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/UnnamedLauncher-self.json ~/Applications/UnnamedLauncher.app/Contents/MacOS/UnnamedLauncher --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            check("the config file is the /tmp override", model.configURL.path.hasPrefix("/tmp/"))
            check("the app is a menu bar app (LSUIElement)", Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true)
            check("an open window gives the app a main menu", NSApp.activationPolicy() == .regular)
            check("the Bindings window opens on Bindings", model.sidebar == .bindings)
            model.sidebar = .contexts
            check("the Bindings window can switch pages", model.sidebar == .contexts)

            await configChecks(model)
            await guideChecks(model)
            await actionChecks()

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// S-001, S-008, S-009: the starter config, reload with errors, Enabled.
    private static func configChecks(_ model: AppModel) async {
        let store = model.store
        let launcher = model.launcher
        // tools/selftest.sh deletes the file first, so launch wrote the starter.
        check("S-001 a missing config file gets the starter config", store.createdStarter
              && store.loaded?.leaders.first?.children.map(\.title) == ["Finder", "Terminal"])
        check("S-002 snapshots and self-tests install no event tap", !launcher.isCapturing)

        let good = try? String(contentsOf: store.url, encoding: .utf8)
        try? Data(#"{ "version": 1, "entries": [{ "keys": "Hyper+Spcae", "title": "C" }] }"#.utf8).write(to: store.url)
        store.reload()
        check("S-008 a reload with errors keeps the last valid config",
              store.loaded?.leaders.first?.title == "Commands" && !store.errors.isEmpty)
        let broken = MenuBarStatus(launcher: launcher, store: store)
        check("S-008 a config error shows in the menu with a warning icon",
              broken.icon == .warning && broken.firstError?.contains("Hyper+Spcae") == true, broken.firstError ?? "no error")
        try? good?.write(to: store.url, atomically: true, encoding: .utf8)
        store.reload()
        let fixed = MenuBarStatus(launcher: launcher, store: store)
        check("S-008 a fixed file reloads and clears the error", store.errors.isEmpty && fixed.firstError == nil)
        check("S-008 the status line says when the config loaded",
              fixed.statusLine?.hasPrefix("Config loaded at") == true || fixed.statusLine == "Created config file"
              || !fixed.missingPermissions.isEmpty, fixed.statusLine ?? "nil")

        launcher.isEnabled = false
        let off = MenuBarStatus(launcher: launcher, store: store)
        check("S-009 turning Enabled off dims the icon and says so",
              off.icon == .off && off.statusLine == "Not capturing leaders" && !launcher.isCapturing)
        check("S-009 the off state is in the VoiceOver label", off.accessibilityLabel == "Unnamed Launcher, off")
        launcher.isEnabled = true
    }

    /// S-005: the Guide shows the path and rows, and never takes focus.
    private static func guideChecks(_ model: AppModel) async {
        let content = SeedData.guideContent
        check("S-005 the Guide lists the leader's keys in file order",
              content.rows.map(\.key) == ["Space", "E", "B", "A", "N", "S"])
        check("S-005 menus are marked, bindings aren't",
              content.rows.first { $0.key == "A" }?.isMenu == true && content.rows.first { $0.key == "E" }?.isMenu == false)
        check("S-005 the footer shows esc and delete", content.cancelKey == "esc" && content.backKey == "delete")
        let front = NSApp.keyWindow
        let guide = model.launcher.guide
        guide.show(content)
        try? await Task.sleep(for: .seconds(0.3))
        check("S-005 the Guide is on screen", guide.isVisible)
        check("S-005 the Guide never becomes the key window",
              !guide.window.canBecomeKey && !guide.window.isKeyWindow && NSApp.keyWindow === front)
        guide.hide()
        try? await Task.sleep(for: .seconds(0.3))
        check("S-007 the Guide hides when the sequence ends", !guide.window.isVisible)
    }

    /// S-006, S-010: Open App and Open, through the real performer for
    /// failures and the recording one for plans (nothing is launched).
    private static func actionChecks() async {
        let system = ActionRunner()
        do throws(PlanError) {
            try await system.run(.application(bundleId: "net.unnamed.not-installed"), id: "missing")
            check("S-006 a missing app is reported", false, "no failure")
        } catch {
            check("S-006 a missing app is reported", error.message == "Couldn't open net.unnamed.not-installed: not installed.", error.message)
        }
        do throws(PlanError) {
            try await system.run(.open(target: "~/net.unnamed.no-such-file"), id: "missing")
            check("S-010 a missing file is reported", false, "no failure")
        } catch {
            check("S-010 a missing file is reported", error.message.hasSuffix("net.unnamed.no-such-file: it doesn't exist."), error.message)
        }

        let recorder = RecordingPerformer()
        let runner = ActionRunner(performer: recorder, home: URL(fileURLWithPath: "/Users/someone"))
        try? await runner.run(.open(target: "~/notes"), id: "notes")
        try? await runner.run(.open(target: "https://example.com/a?b=1"), id: "web")
        check("S-010 file paths and web URLs both open through NSWorkspace", recorder.plans == [
            .open(URL(fileURLWithPath: "/Users/someone/notes")),
            .open(URL(string: "https://example.com/a?b=1")!),
        ], "\(recorder.plans)")
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
