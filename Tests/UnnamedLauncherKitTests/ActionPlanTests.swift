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
