# Architecture review, end of M4 (2026-11-08)

Survey: 5,468 lines in 43 files. The largest is `SelfTest.swift` at 381 lines. Every other file is under 280 lines, and no `private struct` is defined twice. M4 added `ConfigDocument`, `ConfigWriter` and `JSONKeyOrder` to the Kit, with 17 unit tests, plus one shared `BindingsEditor` that the Bindings window and Settings both edit through.

## `SelfTest.swift` split by milestone  [Worth exploring]

Files: `Sources/UnnamedLauncher/SelfTest.swift` (381 lines)
Signal: the largest file, and it grows with every story. It's under the 600 line signal.

**Proposal:** move each `…Checks` function into `SelfTest+M1.swift` through `SelfTest+M4.swift`, keeping `check` and `finish` in `SelfTest.swift`. No behavior changes, and the same 70 checks pass.

**Plan:** do it if M5 or M6 pushes the file past 500 lines.

## Editor state split from the page views  [Speculative]

`BindingsEditor` (213 lines) owns the draft, undo, saving, recording and selection. It's still one concern, editing the config, so leave it.

## Considered, not recommended

- **Replacing the outline's `List` and `DisclosureGroup` with a `Table`.** A `Table` resizes its columns, but SwiftUI's hierarchical `Table` can't reorder rows, and S-028 needs that.

## Top recommendation

**None are Strong.** The code is in good shape for M5.
