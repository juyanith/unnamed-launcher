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
