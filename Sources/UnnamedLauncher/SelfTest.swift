import AppKit
import OSLog
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
            await failureChecks(model)
            await editorChecks(model)

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

        // S-033: saving. A valid edit is written atomically; an invalid one is refused.
        if var document = store.document {
            document.setTitle(KeySequence(parsing: "Hyper+Space F")!, "Files")
            let saved = store.save(document)
            let text = (try? String(contentsOf: store.url, encoding: .utf8)) ?? ""
            check("S-033 a valid edit is saved to the file", (try? saved.get()) != nil && text.contains(#""title": "Files""#))
            var broken = document
            broken.setAction(KeySequence(parsing: "Hyper+Space F")!, "no-such-action")
            let refused = store.save(broken)
            let after = (try? String(contentsOf: store.url, encoding: .utf8)) ?? ""
            check("S-033 an invalid edit is refused and the file isn't changed", (try? refused.get()) == nil && after == text)

            // Another program changes the file: the store reloads within a second.
            let revision = store.revision
            try? text.replacingOccurrences(of: #""title": "Files""#, with: #""title": "Finder""#)
                .write(to: store.url, atomically: true, encoding: .utf8)
            for _ in 0..<30 where store.revision == revision { try? await Task.sleep(for: .milliseconds(100)) }
            check("S-033 a change on disk reloads", store.revision > revision
                  && store.document?.entry(KeySequence(parsing: "Hyper+Space F")!)?.title == "Finder")
        } else {
            check("S-033 the config loads as a document", false)
        }

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
              content.rows.map(\.key) == ["Space", "E", "B", "A", "N", "S", "L", "F"])
        let addressBar = content.rows.first { $0.key == "L" }
        check("S-013 a Choose by App binding with nothing for the app in front is dimmed",
              addressBar?.isAvailable == false && addressBar?.note == "not available in Notes"
              && content.rows.first { $0.key == "F" }?.isAvailable == true)
        check("S-005 menus are marked, bindings aren't",
              content.rows.first { $0.key == "A" }?.isMenu == true && content.rows.first { $0.key == "E" }?.isMenu == false)
        check("S-005 the footer shows esc and delete", content.cancelKey == "esc" && content.backKey == "delete")
        let customText = #"{ "version": 1, "runtime": { "cancelKey": "Q", "backKey": "" }, "entries": [{ "keys": "Hyper+Space", "title": "C" }, { "keys": "Hyper+Space E", "title": "E", "action": "n" }], "actions": { "n": { "type": "noop" } } }"#
        if let custom = try? ConfigLoader.load(Data(customText.utf8)).get() {
            let footer = GuideContent(menu: custom.leaders[0], path: ["C"], config: custom, frontApp: nil)
            check("S-022 the footer shows a custom cancel key and hides Back when it's off",
                  footer.cancelKey == "Q" && footer.backKey == nil)
        } else {
            check("S-022 a config with custom keys loads", false)
        }
        check("S-021 a Guide that's never shown makes no panel", !GuideController().hasPanel)
        let front = NSApp.keyWindow
        let guide = model.launcher.guide
        guide.show(content)
        try? await Task.sleep(for: .seconds(0.3))
        check("S-005 the Guide is on screen", guide.isVisible)
        check("S-005 the Guide never becomes the key window",
              !guide.window.canBecomeKey && !guide.window.isKeyWindow && NSApp.keyWindow === front)
        if let screen = GuideController.frontScreen() {
            check("S-019 the Guide is on the screen of the front app's window",
                  screen.frame.contains(guide.window.frame), "\(guide.window.frame) not in \(screen.frame)")
        } else {
            check("S-019 the front app's window is found", false, "no front window")
        }
        guide.flash()
        check("S-018 an unbound key flashes the Guide", guide.isFlashing)
        try? await Task.sleep(for: Motion.errorFlashHold + .milliseconds(150))
        check("S-018 the flash goes away by itself", !guide.isFlashing)
        guide.hide()
        try? await Task.sleep(for: .seconds(0.3))
        check("S-007 the Guide hides when the sequence ends", !guide.window.isVisible)

        // S-019: top and bottom sit a fifth of the way in from that edge.
        for position in [GuidePlacement.Position.top, .bottom] {
            guide.position = position
            guide.show(content)
            let visible = (GuideController.frontScreen() ?? NSScreen.main!).visibleFrame
            let expected = GuidePlacement.origin(size: guide.window.frame.size, in: visible, position: position)
            check("S-019 \(position.rawValue) puts the Guide where it should be", guide.window.frame.origin == expected,
                  "\(guide.window.frame.origin) vs \(expected)")
            guide.hide()
            try? await Task.sleep(for: .seconds(0.3))
        }
        guide.position = .center

        // S-020: the theme sets the Guide's own appearance.
        guide.theme = "dark"
        check("S-020 a dark theme makes the Guide dark", guide.window.appearance?.name == .darkAqua)
        guide.theme = "light"
        check("S-020 a light theme makes the Guide light", guide.window.appearance?.name == .aqua)
        guide.theme = "system"
        check("S-020 the system theme follows the Mac", guide.window.appearance == nil)
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

        // S-011: a real run, through sh only because this check asks for it.
        let marker = "/tmp/UnnamedLauncher-exec.txt"
        try? FileManager.default.removeItem(atPath: marker)
        let started = ContinuousClock.now
        do throws(PlanError) {
            try await system.run(.exec(command: ["sh", "-c", "pwd > \(marker); echo \"$UL_CHECK\" >> \(marker); sleep 3"],
                                       cwd: nil, env: ["UL_CHECK": "from env"]), id: "exec")
        } catch {
            check("S-011 a command runs", false, error.message)
        }
        check("S-011 the app doesn't wait for a program that starts", ContinuousClock.now - started < .milliseconds(500))
        try? await Task.sleep(for: .seconds(1))
        let lines = ((try? String(contentsOfFile: marker, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        let homePath = ActionPlanner.expandTilde("~", home: .homeDirectory)
        check("S-011 cwd defaults to the home folder", lines.first == homePath, "\(lines)")
        check("S-011 env is added to the inherited environment", lines.dropFirst().first == "from env", "\(lines)")
        // S-012: build the events without posting them, so nothing is typed.
        do throws(PlanError) {
            let chords = try ActionPlanner.chords("Primary+F Cmd+K S")
            let events = try SendShortcut.events(for: chords)
            let flags = events.map(\.flags)
            let codes = events.map { $0.getIntegerValueField(.keyboardEventKeycode) }
            check("S-012 each chord sends a key-down and a key-up", events.count == 6
                  && codes == [0x03, 0x03, 0x28, 0x28, 0x01, 0x01], "\(codes)")
            check("S-012 sent events carry only the chord's own modifiers",
                  flags == [.maskCommand, .maskCommand, .maskCommand, .maskCommand, [], []], "\(flags.map(\.rawValue))")
            check("S-012 sent events are marked so the tap lets them through",
                  events.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == SendShortcut.marker })
        } catch {
            check("S-012 a shortcut builds its events", false, error.message)
        }
        do throws(PlanError) {
            try await system.run(.exec(command: ["net-unnamed-no-such-program"], cwd: nil, env: [:]), id: "missing")
            check("S-011 a program that can't be found is reported", false, "no failure")
        } catch {
            check("S-011 a program that can't be found is reported",
                  error.message == "Couldn't run net-unnamed-no-such-program: it isn't in PATH.", error.message)
        }
    }

    /// S-015: a failure shows in the Guide for two seconds and is logged.
    private static func failureChecks(_ model: AppModel) async {
        let message = "Couldn't open dev.example.missing: not installed."
        model.launcher.report(message, title: "Editor")
        try? await Task.sleep(for: .seconds(0.3))
        let guide = model.launcher.guide
        check("S-015 the Guide shows the failure", guide.isVisible && guide.content?.failure == message)
        try? await Task.sleep(for: Motion.errorMessageHold + .seconds(0.5))
        check("S-015 the failure closes after two seconds", !guide.window.isVisible)
        let logged = (try? OSLogStore(scope: .currentProcessIdentifier))
            .flatMap { try? $0.getEntries(at: $0.position(timeIntervalSinceLatestBoot: 0)) }?  // grid: ok OSLogStore, not a view
            .compactMap { $0 as? OSLogEntryLog }
            .contains { $0.subsystem == "net.unnamed.launcher" && $0.composedMessage.contains(message) } ?? false
        check("S-015 the failure is in the log under net.unnamed.launcher", logged)
    }

    /// M4: the Bindings window's editing, through the same editor the pages use.
    private static func editorChecks(_ model: AppModel) async {
        let editor = model.editor
        let store = model.store
        editor.reloadFromStore()
        let undo = UndoManager()
        undo.groupsByEvent = false
        func step(_ body: () -> Void) { undo.beginUndoGrouping(); body(); undo.endUndoGrouping() }
        func fileLines() -> [String] {
            ((try? String(contentsOf: store.url, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        }
        let commands = KeySequence(parsing: "Hyper+Space")!

        // S-024: New Binding goes at the end of the selected menu, recorder on, unsaved until it has an action.
        editor.selection = commands
        let before = fileLines()
        step { editor.addBinding(undo: undo) }
        let added = editor.selection
        check("S-024 a new binding goes at the end of the selected menu",
              added != nil && editor.draft.children(of: commands).last == added, "\(String(describing: added))")
        check("S-024 the new binding's key recorder is on", editor.recording == added && editor.focus == .key)
        check("S-024 a binding without an action isn't saved, and says why",
              fileLines() == before && editor.draftErrors.first?.message.hasPrefix("Choose an action") == true)
        editor.stopRecording()

        // S-025: keys are checked and stored in canonical form.
        if let added {
            check("S-025 a key that's taken in the menu is refused",
                  editor.setKey(added, Chord(key: .f), undo: undo)?.contains("already used") == true)
            check("S-025 a key inside a menu can't have modifiers",
                  editor.setKey(added, Chord(modifiers: .command, key: .k), undo: undo) != nil)
            check("S-025 the cancel key is refused", editor.setKey(added, Chord(key: .escape), undo: undo)?.contains("cancel key") == true)
            var problem: String?
            step { problem = editor.setKey(added, Chord(parsing: "k")!, undo: undo) }
            let renamed = KeySequence(parsing: "Hyper+Space K")!
            check("S-025 a recorded key is stored in canonical form", problem == nil && editor.selection == renamed
                  && editor.draft.entry(renamed) != nil)

            // S-026: choosing an action saves it, changing only that line.
            check("S-026 the action popup lists every action and New Action…",
                  editor.actionChoices == editor.draft.actionOrder.filter { editor.draft.config.actions[$0] != nil } + [BindingsEditor.newActionTag])
            step { editor.setAction(renamed, "open-finder", undo: undo) }
            let withBinding = fileLines()
            check("S-026 a binding with its action is saved", editor.draftErrors.isEmpty
                  && withBinding.contains { $0.contains(#""keys": "Hyper+Space K""#) })
            step { editor.setTitle(renamed, "Finder Again", undo: undo) }
            let retitled = fileLines()
            check("S-026 changing the title rewrites only that entry",
                  retitled.count == withBinding.count && zip(retitled, withBinding).filter { $0 != $1 }.count == 1)

            // S-028: reordering is saved, stays in its menu, and the Guide follows.
            step { editor.move(in: commands, from: [2], to: 0, undo: undo) }
            let order = editor.draft.children(of: commands).map { $0.lastStep!.key.name }
            let guide = store.loaded.map { GuideContent(menu: $0.leaders[0], path: ["Commands"], config: $0, frontApp: nil) }
            check("S-028 a new order is written and the Guide lists it", order == ["K", "F", "T"]
                  && guide?.rows.map(\.key) == ["K", "F", "T"], "\(order)")
            var moved = editor.draft
            let unchanged = moved
            moved.moveEntry(renamed, before: KeySequence(parsing: "Ctrl+W 1")!)
            check("S-028 an item can't be dropped into a different menu", moved == unchanged)

            // S-029: Sort Alphabetically, and undo.
            step { editor.sort(commands, undo: undo) }
            check("S-029 sorting puts the menu in order", editor.draft.children(of: commands).map { $0.lastStep!.key.name } == ["F", "K", "T"])
            undo.undo()
            check("S-029 Sort Alphabetically can be undone", editor.draft.children(of: commands).map { $0.lastStep!.key.name } == ["K", "F", "T"])

            // S-027: deleting a menu with entries counts them, and undo brings them back.
            let apps = editor.draft.config.entries.count
            step { editor.addMenu(undo: undo) }
            if let menu = editor.selection {
                editor.stopRecording()
                step { editor.selection = menu; editor.addBinding(undo: undo) }
                if let child = editor.selection { step { editor.setAction(child, "open-terminal", undo: undo) } }
                editor.stopRecording()
                check("S-027 a menu's entries are counted before deleting", editor.descendantCount(menu) == 1)
                step { editor.delete(menu, undo: undo) }
                check("S-027 deleting removes the menu and what's under it", editor.draft.config.entries.count == apps)
                undo.undo()
                check("S-027 ⌘Z restores them", editor.draft.index(of: menu) != nil && editor.descendantCount(menu) == 1)
            }
        }

        // S-030: renaming an action updates bindings; deleting one in use is blocked.
        step { editor.edit("Rename Action", undo: undo) { try? $0.renameAction("open-finder", to: "finder") } }
        check("S-030 renaming an action updates every binding", editor.draft.users(of: "finder").count >= 2
              && editor.draft.config.actions["open-finder"] == nil && fileLines().contains { $0.contains(#""action": "finder""#) })
        var blocked = editor.draft
        do throws(ConfigDocument.EditError) {
            try blocked.removeAction("finder")
            check("S-030 deleting an action in use is blocked", false)
        } catch {
            check("S-030 deleting an action in use is blocked and lists its users", {
                if case let .inUse(users) = error { return users.contains("Hyper+Space F") } else { return false }
            }())
        }
        check("S-030 an app's bundle id comes from its bundle", Bundle(url: URL(fileURLWithPath: "/System/Applications/Calculator.app"))?.bundleIdentifier == "com.apple.calculator")

        // S-031: contexts reorder, and the order is saved.
        step { editor.edit("Contexts", undo: undo) { $0.config.contexts = [.init(id: "one", apps: []), .init(id: "two", apps: [])] } }
        step { editor.edit("Move Context", undo: undo) { $0.moveContexts(from: [1], to: 0) } }
        check("S-031 a new context order is saved", store.document?.config.contexts.map(\.id) == ["two", "one"])

        // S-032: settings are saved like any other edit.
        step { editor.edit("Change Delay", undo: undo) { $0.config.runtime.hudDelayMs = SettingsValues.milliseconds(-100) } }
        check("S-032 a negative delay becomes 0", store.loaded?.config.runtime.hudDelayMs == 0)
        step { editor.edit("Change Delay", undo: undo) { $0.config.runtime.hudDelayMs = 400 } }
        check("S-032 a setting is written to the file", fileLines().contains { $0.contains(#""hudDelayMs": 400"#) })

        // S-034: clicking an error selects the row and the field it's about.
        step { editor.addBinding(undo: undo) }
        if let issue = editor.draftErrors.first {
            editor.stopRecording()
            editor.selection = nil
            editor.show(issue)
            check("S-034 clicking an error selects its row and focuses the field",
                  editor.selection?.description == issue.subject && editor.focus == .action, issue.message)
        }
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
