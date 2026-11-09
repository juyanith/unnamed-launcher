# Architecture review, end of M6 (2026-11-08)

Version one is complete: all 44 stories in STORIES.md are done.

**Survey.** 6,031 lines. The largest file is `ConfigDocument.swift` at 295 lines, and nothing is near the 600 line signal. The fix log has one entry (the Guide's fade), and no area has repeated bugs.

**Tests.** There are 99 unit tests in the Kit and 82 self-test checks. Snapshot mode covers every surface except the menu bar menu itself, which can't be captured.

**Most-changed files.** The files that changed most in this session are the test hooks: `SelfTest` (20 commits) and `Snapshot` (11). After those comes `Launcher` (11), the one place that ties the parts together.

**Seams.**
- `ConfigLocation`, through `APP_STORE`.
- `Launcher.start(captureKeys:seed:)`.
- `KeyEvent` into the pure `SequenceEngine`.
- `ActionPerformer`, with its system and recording adapters.
- `ConfigStore` as the one owner of the file.

Dependencies point one way, from the app to the Kit.

## `Launcher` split into capture and session  [Worth exploring]

Files: `Sources/UnnamedLauncher/Launcher.swift` (201 lines, 43 members)
Signal: one feature touched it in every milestone. It holds permissions, Secure Input, the tap, the engine box, the Guide schedule and its timer, running actions, failure reporting, and "has run a sequence".

**Proposal:** split it in two.
- `KeyboardAccess` takes permissions, Secure Input, the tap, Enabled and relaunch: the "can we see keys" half, which the menu bar reads.
- `SequenceSession` takes the engine box, the schedule and timer, the Guide and actions: the "what a sequence does" half.

`Launcher` would then just wire the two together. No behavior changes, and the same 82 self-test checks pass.

**Benefits:** the menu bar status reads one small type, and timing changes stay away from permission code.

**Plan:** do it before the next feature that touches both halves, such as double-tap modifier leaders from the Later list, which need both the tap and the engine.

## Snapshot pages from a table  [Speculative]

`Snapshot.swift` (195 lines) repeats the same "for light and dark, set up, wait, capture" loop seven times. A list of named pages with a setup closure each would shrink it and make adding a page one line. It works as it is, though, and only agents read it.

## Considered, not recommended

- **Moving `EngineBox` out of `KeyCapture.swift`.** It's the tap's partner, and it's small.
- **A full JSON Schema validator in the tests.** It would be a dependency for a check the current tests already cover, piece by piece, against the app's own rules.
- **Keeping unsaved edits when the file changes on disk.** SPEC.md makes the file the source of truth, and an outside edit while a draft has errors is rare.

## Top recommendation

**None are Strong.** The codebase is in good shape to ship. Do the `Launcher` split when the next feature needs both halves.
