import Foundation
import Testing
@testable import UnnamedLauncherKit

private let handWritten = """
{
  "version": 1,
  "runtime": { "hudDelayMs": 500 },
  "entries": [
    { "keys": "Hyper+Space", "title": "Commands" },
    { "keys": "Hyper+Space Z", "title": "Zed", "action": "zed" },
    { "keys": "Hyper+Space A", "title": "Apps" },
    { "keys": "Hyper+Space 1", "title": "One", "action": "browse" },
    { "keys": "Hyper+Space A T", "title": "Terminal", "action": "term" },
    { "keys": "Hyper+Space A M", "title": "Mail", "action": "mail" },
    { "keys": "Hyper+Space Space", "title": "Spot", "action": "zed" }
  ],
  "actions": {
    "zed": { "type": "application", "bundleId": "dev.zed.Zed" },
    "term": { "type": "exec", "command": ["open", "-a", "Terminal"], "env": { "B": "2", "A": "1" } },
    "browse": {
      "type": "contextual",
      "variants": { "web": { "type": "send", "keys": "Cmd+L" } },
      "fallback": { "type": "noop" }
    },
    "mail": { "type": "open", "target": "mailto:me@example.com" }
  },
  "contexts": [{ "id": "web", "apps": ["com.apple.Safari"] }]
}
"""

private func doc() throws -> ConfigDocument { try ConfigDocument(data: Data(handWritten.utf8)) }
private func p(_ s: String) -> KeySequence { KeySequence(parsing: s)! }
private func keys(_ d: ConfigDocument) -> [String] { d.config.entries.map(\.keys) }

@Suite("Saving the config (S-033)")
struct WriterTests {
    @Test("Action order is read from the file, not sorted")
    func actionOrder() throws {
        #expect(try doc().actionOrder == ["zed", "term", "browse", "mail"])
        #expect(JSONKeyOrder.keys(ofTopLevelObject: "actions", in: Data(#"{"a":[1,{"x":"}"}],"actions":{"q\"":{},"b":1}}"#.utf8)) == ["q\"", "b"])
    }

    @Test("Saved with no edits, entry order, action order and contexts are the same")
    func roundTrip() throws {
        let original = try doc()
        let reread = try ConfigDocument(data: original.data())
        #expect(reread == original)
        #expect(keys(reread) == keys(original))
        #expect(reread.actionOrder == ["zed", "term", "browse", "mail"])
        // And writing again gives the same bytes.
        #expect(reread.data() == original.data())
    }

    @Test("Output is one line per entry, action and context, with defaults left out")
    func layout() throws {
        let text = String(decoding: try doc().data(), as: UTF8.self)
        let expected = """
        {
          "version": 1,
          "runtime": { "hudDelayMs": 500 },
          "entries": [
            { "keys": "Hyper+Space", "title": "Commands" },
            { "keys": "Hyper+Space Z", "title": "Zed", "action": "zed" },
            { "keys": "Hyper+Space A", "title": "Apps" },
            { "keys": "Hyper+Space 1", "title": "One", "action": "browse" },
            { "keys": "Hyper+Space A T", "title": "Terminal", "action": "term" },
            { "keys": "Hyper+Space A M", "title": "Mail", "action": "mail" },
            { "keys": "Hyper+Space Space", "title": "Spot", "action": "zed" }
          ],
          "actions": {
            "zed": { "type": "application", "bundleId": "dev.zed.Zed" },
            "term": { "type": "exec", "command": ["open", "-a", "Terminal"], "env": { "A": "1", "B": "2" } },
            "browse": { "type": "contextual", "variants": { "web": { "type": "send", "keys": "Cmd+L" } }, "fallback": { "type": "noop" } },
            "mail": { "type": "open", "target": "mailto:me@example.com" }
          },
          "contexts": [
            { "id": "web", "apps": ["com.apple.Safari"] }
          ]
        }

        """
        #expect(text == expected)
    }

    @Test("An edit changes only the lines it touches")
    func smallDiff() throws {
        var d = try doc()
        let before = String(decoding: d.data(), as: UTF8.self).split(separator: "\n")
        d.setTitle(p("Hyper+Space Z"), "Zed Editor")
        let after = String(decoding: d.data(), as: UTF8.self).split(separator: "\n")
        #expect(zip(before, after).filter { $0 != $1 }.count == 1)
    }

    @Test("$schema is kept")
    func schema() throws {
        let d = try ConfigDocument(data: Data(#"{ "$schema": "./config.schema.json", "version": 1, "entries": [] }"#.utf8))
        #expect(String(decoding: d.data(), as: UTF8.self).contains(#""$schema": "./config.schema.json""#))
    }
}

@Suite("Editing entries (S-024 to S-029)")
struct EditTests {
    @Test("A new entry goes at the end of the menu with the first free key")
    func add() throws {
        var d = try doc()
        let path = d.addEntry(under: p("Hyper+Space A"), title: "New", action: "zed")
        #expect(path.description == "Hyper+Space A A")
        #expect(d.children(of: p("Hyper+Space A")) == [p("Hyper+Space A T"), p("Hyper+Space A M"), path])
        #expect(keys(d)[6] == "Hyper+Space A A")
        let leader = d.addEntry(under: nil, title: "Leader", action: nil)
        #expect(leader.description == "Hyper+A" && keys(d).last == "Hyper+A")
    }

    @Test("A new key skips taken keys and the cancel and back keys")
    func freeKey() throws {
        var d = try ConfigDocument(data: Data(json(entries: minimalEntries, actions: minimalActions, runtime: #"{ "cancelKey": "A", "backKey": "B" }"#).utf8))
        #expect(d.addEntry(under: p("Hyper+Space"), title: "x", action: "edit").description == "Hyper+Space C")
    }

    @Test("A key already taken in the menu, or the cancel or back key, is refused")
    func keyProblems() throws {
        var d = try doc()
        #expect(d.keyProblem(for: p("Hyper+Space Z"), newKey: Chord(key: .a)) == .keyTaken("Hyper+Space A"))
        #expect(d.keyProblem(for: p("Hyper+Space Z"), newKey: Chord(key: .escape)) == .reservedKey("Escape"))
        #expect(d.keyProblem(for: p("Hyper+Space Z"), newKey: Chord(key: .z)) == nil)
        #expect(throws: ConfigDocument.EditError.self) { try d.changeKey(of: p("Hyper+Space Z"), to: Chord(key: .a)) }
    }

    @Test("Changing a menu's key renames everything under it, in canonical form")
    func changeKey() throws {
        var d = try doc()
        let new = try d.changeKey(of: p("hyper+space a"), to: Chord(parsing: "b")!)
        #expect(new.description == "Hyper+Space B")
        #expect(keys(d).filter { $0.hasPrefix("Hyper+Space B") } == ["Hyper+Space B", "Hyper+Space B T", "Hyper+Space B M"])
        try d.changeKey(of: p("Hyper+Space"), to: Chord(parsing: "ctrl+alt+k")!)
        #expect(keys(d).allSatisfy { $0.hasPrefix("Ctrl+Alt+K") })
    }

    @Test("Title and action changes touch only that entry")
    func titleAndAction() throws {
        var d = try doc()
        let before = d.config.entries
        d.setAction(p("Hyper+Space 1"), "mail")
        #expect(zip(before, d.config.entries).filter { $0 != $1 }.count == 1)
    }

    @Test("Removing a menu removes everything under it and says how many")
    func remove() throws {
        var d = try doc()
        #expect(d.removeEntry(p("Hyper+Space A")) == 3)
        #expect(!keys(d).contains { $0.hasPrefix("Hyper+Space A") })
    }

    @Test("Moving keeps items in their menu and carries their children")
    func move() throws {
        var d = try doc()
        // Children of Commands: Z, A, 1, Space. Move A (with T, M) before Z.
        d.moveChildren(of: p("Hyper+Space"), from: [1], to: 0)
        #expect(d.children(of: p("Hyper+Space")).map { $0.lastStep!.key.name } == ["A", "Z", "1", "Space"])
        #expect(d.children(of: p("Hyper+Space A")) == [p("Hyper+Space A T"), p("Hyper+Space A M")])
        // Move Z to the end.
        d.moveChildren(of: p("Hyper+Space"), from: [1], to: 4)
        #expect(d.children(of: p("Hyper+Space")).map { $0.lastStep!.key.name } == ["A", "1", "Space", "Z"])
        // A move into another menu is ignored.
        let unchanged = d
        d.moveEntry(p("Hyper+Space Z"), before: p("Hyper+Space A T"))
        #expect(d == unchanged)
        // Still valid after all that.
        #expect((try? d.validate().get()) != nil)
    }

    @Test("Sort: named keys alphabetically with F-keys by number, then digits, then letters")
    func sort() throws {
        #expect([KeyName.z, .f10, .d1, .space, .f2, .a, .enter, .d0].sorted(by: ConfigDocument.sortsBefore)
                == [.enter, .f2, .f10, .space, .d0, .d1, .a, .z])
        var d = try doc()
        d.sortChildren(of: p("Hyper+Space"))
        #expect(d.children(of: p("Hyper+Space")).map { $0.lastStep!.key.name } == ["Space", "1", "A", "Z"])
        #expect((try? d.validate().get()) != nil)
    }
}

@Suite("Editing actions and contexts (S-030, S-031)")
struct ActionEditTests {
    @Test("Renaming an action updates every binding that uses it")
    func rename() throws {
        var d = try doc()
        try d.renameAction("zed", to: "editor")
        #expect(d.users(of: "editor").map(\.description) == ["Hyper+Space Z", "Hyper+Space Space"])
        #expect(d.actionOrder.first == "editor" && d.config.actions["zed"] == nil)
        #expect(throws: ConfigDocument.EditError.idTaken("term")) { try d.renameAction("editor", to: "term") }
    }

    @Test("Deleting an action in use is blocked and lists its users")
    func remove() throws {
        var d = try doc()
        #expect(throws: ConfigDocument.EditError.inUse(["Hyper+Space Z", "Hyper+Space Space"])) { try d.removeAction("zed") }
        d.removeEntry(p("Hyper+Space A M"))
        try d.removeAction("mail")
        #expect(d.config.actions["mail"] == nil && !d.actionOrder.contains("mail"))
    }

    @Test("New action ids don't clash")
    func freeID() throws {
        var d = try doc()
        #expect(d.freeActionID() == "new-action")
        d.setAction(id: "new-action", .noop)
        #expect(d.freeActionID() == "new-action-2" && d.actionOrder.last == "new-action")
    }

    @Test("Contexts reorder and rename, and variants follow")
    func contexts() throws {
        var d = try doc()
        d.config.contexts.append(Config.Context(id: "code", apps: ["dev.zed.Zed"]))
        d.moveContexts(from: [1], to: 0)
        #expect(d.config.contexts.map(\.id) == ["code", "web"])
        try d.renameContext("web", to: "browser")
        guard case let .contextual(variants, _) = d.config.actions["browse"] else { Issue.record("no variants"); return }
        #expect(variants["browser"] != nil && variants["web"] == nil)
    }
}
