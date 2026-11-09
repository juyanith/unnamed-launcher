import Foundation
import Testing
@testable import UnnamedLauncherKit

let testHome = URL(fileURLWithPath: "/Users/someone")

@Suite("Open (S-010)")
struct OpenPlanTests {
    @Test("A leading ~ expands to the home folder, and nothing else is expanded", arguments: [
        ("~", "/Users/someone"),
        ("~/notes", "/Users/someone/notes"),
        ("~notes", "~notes"),
        ("~other/notes", "~other/notes"),
        ("/tmp/~/x", "/tmp/~/x"),
        ("$HOME/notes", "$HOME/notes"),
        ("notes/*.md", "notes/*.md"),
    ])
    func tilde(_ input: String, expected: String) {
        #expect(ActionPlanner.expandTilde(input, home: testHome) == expected)
    }

    @Test("Paths become file URLs and URLs stay URLs")
    func targets() throws {
        #expect(try ActionPlanner.plan(.open(target: "~/notes"), home: testHome) == .open(URL(fileURLWithPath: "/Users/someone/notes")))
        #expect(try ActionPlanner.plan(.open(target: "/Applications"), home: testHome) == .open(URL(fileURLWithPath: "/Applications")))
        #expect(try ActionPlanner.plan(.open(target: "https://example.com"), home: testHome) == .open(URL(string: "https://example.com")!))
        #expect(try ActionPlanner.plan(.open(target: "mailto:a@b.c"), home: testHome) == .open(URL(string: "mailto:a@b.c")!))
    }

    @Test("A relative path is an error, not a guess")
    func relative() {
        #expect(throws: PlanError.self) { try ActionPlanner.plan(.open(target: "notes"), home: testHome) }
    }
}

@Suite("Do Nothing (S-014)")
struct NoopPlanTests {
    @Test("A noop plans nothing")
    func noop() throws {
        #expect(try ActionPlanner.plan(.noop, home: testHome) == .nothing)
    }
}

@Suite("Run Command (S-011)")
struct ExecPlanTests {
    @Test("Arguments pass literally; only a leading ~ in command and cwd expands")
    func literal() throws {
        let plan = try ActionPlanner.plan(.exec(command: ["~/bin/tool", "~/notes", "$HOME", "*.md", "a b", "x~/y"],
                                                cwd: "~/work", env: ["K": "~/v"]), home: testHome)
        #expect(plan == .spawn(program: "/Users/someone/bin/tool",
                               arguments: ["/Users/someone/notes", "$HOME", "*.md", "a b", "x~/y"],
                               cwd: URL(fileURLWithPath: "/Users/someone/work", isDirectory: true),
                               env: ["K": "~/v"]))
    }

    @Test("cwd defaults to the home folder")
    func defaultCwd() throws {
        guard case let .spawn(_, _, cwd, _) = try ActionPlanner.plan(.exec(command: ["zed"], cwd: nil, env: [:]), home: testHome) else {
            Issue.record("not a spawn"); return
        }
        #expect(cwd == testHome)
    }

    @Test("An empty command is an error")
    func empty() {
        #expect(throws: PlanError.self) { try ActionPlanner.plan(.exec(command: [], cwd: nil, env: [:]), home: testHome) }
    }

    @Test("Programs are found in the search path, in order; paths are checked as given")
    func locate() {
        let files: Set<String> = ["/opt/homebrew/bin/zed", "/usr/local/bin/zed", "/usr/bin/true"]
        let path = ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        #expect(ActionPlanner.locate("zed", searchPath: path, isExecutable: files.contains) == "/opt/homebrew/bin/zed")
        #expect(ActionPlanner.locate("/usr/bin/true", searchPath: [], isExecutable: files.contains) == "/usr/bin/true")
        #expect(ActionPlanner.locate("nope", searchPath: path, isExecutable: files.contains) == nil)
    }

    @Test("The search path keeps PATH first and adds the usual folders once")
    func searchPath() {
        let dirs = ActionPlanner.searchPath(environmentPath: "/usr/bin:/bin:/custom", home: testHome)
        #expect(Array(dirs.prefix(3)) == ["/usr/bin", "/bin", "/custom"])
        #expect(dirs.contains("/opt/homebrew/bin") && dirs.contains("/Users/someone/.local/bin"))
        #expect(dirs.filter { $0 == "/usr/bin" }.count == 1)
    }
}

@Suite("Send Shortcut (S-012)")
struct SendPlanTests {
    @Test("send parses one or more chords, and Primary maps to ⌘")
    func chords() throws {
        #expect(try ActionPlanner.plan(.send(keys: "Primary+F"), home: testHome) == .send([Chord(modifiers: .command, key: .f)]))
        #expect(try ActionPlanner.chords("Cmd+K  S") == [Chord(modifiers: .command, key: .k), Chord(key: .s)])
        #expect(try ActionPlanner.chords("Hyper+1") == [Chord(modifiers: .hyper, key: .d1)])
    }

    @Test("Bad or empty keys are errors", arguments: ["", "Cmd+Spcae", "Super+F"])
    func bad(_ keys: String) {
        #expect(throws: PlanError.self) { try ActionPlanner.chords(keys) }
    }
}

@Suite("Choose by App (S-013)")
struct ContextTests {
    let contexts = [
        Config.Context(id: "browser", apps: ["com.google.Chrome", "com.apple.Safari"]),
        Config.Context(id: "chromium", apps: ["com.google.Chrome"]),
        Config.Context(id: "editor", apps: ["dev.zed.Zed"]),
    ]
    let cmdL = Config.Action.send(keys: "Cmd+L")
    let chromeOnly = Config.Action.send(keys: "Cmd+Shift+L")
    let cmdF = Config.Action.send(keys: "Cmd+F")

    @Test("The first context in contexts order with the app and a variant wins")
    func order() {
        let action = Config.Action.contextual(variants: ["chromium": chromeOnly, "browser": cmdL], fallback: cmdF)
        #expect(ContextResolver.resolve(action, frontApp: "com.google.Chrome", contexts: contexts) == cmdL)
        #expect(ContextResolver.resolve(action, frontApp: "com.apple.Safari", contexts: contexts) == cmdL)
        // A context with the app but no variant is skipped.
        let skip = Config.Action.contextual(variants: ["chromium": chromeOnly], fallback: nil)
        #expect(ContextResolver.resolve(skip, frontApp: "com.google.Chrome", contexts: contexts) == chromeOnly)
    }

    @Test("Otherwise the fallback runs; with no fallback the action is unavailable")
    func fallback() {
        let withFallback = Config.Action.contextual(variants: ["browser": cmdL], fallback: cmdF)
        #expect(ContextResolver.resolve(withFallback, frontApp: "com.apple.Notes", contexts: contexts) == cmdF)
        #expect(ContextResolver.resolve(withFallback, frontApp: nil, contexts: contexts) == cmdF)
        let without = Config.Action.contextual(variants: ["browser": cmdL], fallback: nil)
        #expect(ContextResolver.resolve(without, frontApp: "com.apple.Notes", contexts: contexts) == nil)
    }

    @Test("Other kinds of action are always available")
    func plain() {
        #expect(ContextResolver.resolve(cmdF, frontApp: nil, contexts: []) == cmdF)
    }
}

@Suite("Choose by App in a sequence (S-013)")
struct ContextSequenceTests {
    let text = json(entries: """
    { "keys": "Hyper+Space", "title": "Commands" },
    { "keys": "Hyper+Space L", "title": "Address Bar", "action": "address" }
    """, actions: #"{ "address": { "type": "contextual", "variants": { "browser": { "type": "send", "keys": "Cmd+L" } } } }"#,
    contexts: #"[{ "id": "browser", "apps": ["com.apple.Safari"] }]"#)

    func start(in app: String) throws -> SequenceEngine {
        var engine = SequenceEngine(config: try load(text).get())
        engine.setFrontApp(app)
        _ = engine.handle(.down(keyCode: KeyName.space.keyCode!, modifiers: .hyper, isRepeat: false))
        return engine
    }

    @Test("Pressing an unavailable binding gives error feedback, runs nothing, and stays")
    func unavailable() throws {
        var engine = try start(in: "com.apple.Notes")
        let output = engine.handle(.down(keyCode: KeyName.l.keyCode!, modifiers: [], isRepeat: false))
        guard case let .unavailable(binding, path) = output.effect else { Issue.record("\(String(describing: output.effect))"); return }
        #expect(output.consume && binding.title == "Address Bar" && path == ["Commands"] && engine.isActive)
    }

    @Test("In a matching app the binding runs, for the app that was in front at the leader")
    func available() throws {
        var engine = try start(in: "com.apple.Safari")
        // Switching apps mid-sequence doesn't change the answer.
        engine.setFrontApp("com.apple.Notes")
        guard case let .run(binding, frontApp) = engine.handle(.down(keyCode: KeyName.l.keyCode!, modifiers: [], isRepeat: false)).effect else {
            Issue.record("no run"); return
        }
        #expect(binding.title == "Address Bar" && frontApp == "com.apple.Safari")
    }
}

@Suite("Do Nothing in a sequence (S-014)")
struct NoopSequenceTests {
    @Test("A noop binding ends the sequence and does nothing else")
    func noop() throws {
        let text = json(entries: """
        { "keys": "Hyper+Space", "title": "Commands" },
        { "keys": "Hyper+Space R", "title": "Reserved", "action": "reserved" }
        """, actions: #"{ "reserved": { "type": "noop" } }"#)
        let config = try load(text).get()
        var engine = SequenceEngine(config: config)
        _ = engine.handle(.down(keyCode: KeyName.space.keyCode!, modifiers: .hyper, isRepeat: false))
        guard case let .run(binding, _) = engine.handle(.down(keyCode: KeyName.r.keyCode!, modifiers: [], isRepeat: false)).effect else {
            Issue.record("no run"); return
        }
        #expect(!engine.isActive)
        #expect(try ActionPlanner.plan(config.config.actions[binding.action!]!, home: testHome) == .nothing)
    }
}
