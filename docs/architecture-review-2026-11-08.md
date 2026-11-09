# Architecture review, end of M1 (2026-11-08)

Survey: 2,546 lines in 25 files. The largest file is `Config.swift` (225 lines), and no type is over 200 lines. There are no duplicated `private struct`s and no fix log yet. There are two targets: `UnnamedLauncherKit` holds the pure config, validation and sequence engine logic, with 39 unit tests, and `UnnamedLauncher` holds the AppKit/SwiftUI shell. Dependencies point one way, from the app to the Kit.

## Event tap on its own thread  [Strong]  Done

Files: `Sources/UnnamedLauncher/KeyCapture.swift` (109 lines), `Sources/UnnamedLauncher/Launcher.swift` (129 lines)
Signal: slow work on a real-time path. SPEC.md says the tap callback "must never block".

**Problem:** the tap's run loop source is on the main run loop. Every keystroke on the Mac, in every app, waits for the main thread to be free before it's delivered. When the main thread is busy, all typing stalls. That could be SwiftUI laying out the Bindings window outline (M4), a config reload, or an `NSWorkspace` call. If the stall lasts long enough, macOS turns the tap off (`tapDisabledByTimeout`). Today the main thread is nearly idle, so this doesn't show, but M2 adds Run Command and Send Shortcut, and M4 adds a large outline view.

**Proposal:** run the tap on a dedicated thread with its own run loop. The engine lives in a lock-protected box both threads can reach. The tap thread decides consume or pass at once, and effects (show the Guide, run an action) go to the main queue in order.

```swift
nonisolated final class EngineBox: Sendable {
    func handle(_ event: KeyEvent) -> SequenceOutput   // tap thread
    func replace(_ config: LoadedConfig)                // main thread, on reload
    func reset()
}
final class KeyCapture {
    init(handler: @escaping @Sendable (KeyEvent) -> Bool)  // called on the tap thread
    func start() -> Bool
    func stop()
}
```

**Benefits:** the main thread can no longer delay keystrokes, and the change stays inside `KeyCapture` and `Launcher`. The engine is already a pure `Sendable` struct, so nothing in the Kit changes.

**Proof of same behavior:** the 39 Kit unit tests and 20 self-test checks pass before and after, plus a manual check that Hyper+Space still shows the Guide and a binding still opens its app.

**Plan:** one commit, made up of the tap thread, `EngineBox`, and `Launcher` dispatching effects to the main queue.

## Actions behind a seam  [Worth exploring]

Files: `Sources/UnnamedLauncher/ActionRunner.swift` (37 lines)
Signal: a dependency can't be replaced in a test. `ActionRunner` calls `NSWorkspace` directly, so the self-test can only check the "not installed" path. A real launch would steal focus during the test.

**Proposal:** M2 adds Open, Run Command and Send Shortcut. Each should go through a small `ActionPerformer` protocol (open URL, open app, spawn process, post events), with a real adapter and a recording adapter for the self-test. The self-test can then check, for example, that `["zed", "~/notes"]` becomes `/usr/bin/env zed /Users/van/notes` without running anything.

**Plan:** do this inside S-010 and S-011, not as a separate refactor.

## Launcher becoming the place for everything  [Speculative]

`Launcher` owns permissions, capture, the engine, the Guide and actions, in 129 lines. It's fine for now. If M3's timers (delay, timeout, flash) land there too, split out a `SequenceSession` that owns the timers and the Guide's state.

## Top recommendation

**Event tap on its own thread.** It meets a SPEC requirement, it's contained to two files, and it has to happen before M2 and M4 put more work on the main thread.

## Considered, not recommended

- **Splitting `ConfigValidator.validate` (140 lines) into one function per rule.** It reads top to bottom in SPEC order, and the tests already cover each rule.
- **Moving `SelfTest` and `Snapshot` out of the app target.** They're the template's standard test hooks, and they refuse to run without a `/tmp` config.
- **An ordered dictionary for `actions`, so writing the file back keeps action order.** Not needed until S-033 (M4). Decide it there.
