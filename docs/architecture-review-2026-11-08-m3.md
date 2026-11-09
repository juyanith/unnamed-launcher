# Architecture review, end of M3 (2026-11-08)

Survey: 3,469 lines in 33 files, and no file is over 240 lines. M3 added `GuideSchedule` and `GuidePlacement` to the Kit, both pure and unit-tested, and split the Guide panel out of `Guide.swift`, as the M2 review suggested. The fix log is unchanged, with one entry.

## Config editing as a document model in the Kit  [Strong, as part of M4]

Files: `Sources/UnnamedLauncherKit/Config.swift`, a new `ConfigDocument.swift` and `ConfigWriter.swift`
Signal: before a big feature. M4's twelve stories all change the config and write it back.

**Problem:** today the config can only be read. Every M4 edit has to rewrite a flat, path-keyed entry list: add at the end of a menu, delete a subtree, move a subtree, change a key, which renames every descendant, sort a menu, and rename an action id everywhere it's used. Doing that in SwiftUI views would scatter path arithmetic across pages, with no tests.

Writing back has two traps:
- **Action order is lost.** `actions` is a JSON object, so `Codable` decodes it into a dictionary with no order. S-033 needs the original order kept.
- **`JSONEncoder` rewrites the whole file** in its own layout and order, so every edit would make a large diff.

**Proposal:**
- **`ConfigDocument`, a value type in the Kit:** a `Config` plus the original action order, with one method per edit. Each edit works on the flat list with as small a change as it can, so untouched entries keep their place in the file.
- **`ConfigWriter`:** writes a fixed key order, with one line per entry, action and context. Defaults are left out, so a short file stays short.
- **`JSONKeyOrder`:** a small scanner that reads the key order of the `actions` object from the file's text.

```swift
public struct ConfigDocument: Sendable, Equatable {
    public var config: Config
    public var actionOrder: [String]
    public init(data: Data) throws
    public mutating func addEntry(under parent: KeySequence?, title: String, action: String?) -> KeySequence
    public mutating func removeEntry(_ path: KeySequence)                 // and everything under it
    public mutating func moveEntry(_ path: KeySequence, before sibling: KeySequence?)
    public mutating func changeKey(of path: KeySequence, to step: Chord) // renames descendants
    public mutating func sortChildren(of menu: KeySequence)
    public mutating func renameAction(_ id: String, to newID: String)   // updates bindings
    public func data() -> Data                                           // ConfigWriter
}
```

**Benefits:** every edit and the round trip are unit-tested with no UI. The pages call one method per command, and undo is a snapshot of one value.

**Plan:** build it with S-033, before any page that edits.

## `Launcher` and `ConfigStore` ownership  [Worth exploring]

The Bindings window, Settings and the engine will all read the config. Keep `ConfigStore` as the one owner of the file, with read, atomic write, watch and reload. Pages edit a draft `ConfigDocument` and hand it to the store to save. A draft with errors is never written.

## Considered, not recommended

- **Replacing the flat entry list with a nested tree in the file.** SPEC.md chose the flat list on purpose: every entry reads and diffs on its own, and every depth has the same shape.
- **A third-party JSON library that keeps key order.** The format needs to preserve only one object's order, and a small scanner covers it with no dependency.

## Top recommendation

**`ConfigDocument`, `ConfigWriter` and `JSONKeyOrder` in the Kit, built with S-033.**
