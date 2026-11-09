# Architecture review, end of M2 (2026-11-08)

Survey: 3,119 lines in 29 files. The largest is `Guide.swift` (282 lines), and no type is over 200 lines. The fix log has one entry: the Guide's state depended on its fade. The most-changed code in M2 was `SelfTest.swift`, `Launcher.swift` and `Snapshot.swift`. That's expected, since every story adds checks there.

M2 added an `ActionPlanner` (pure, in the Kit, tested) and an `ActionPerformer` seam with two adapters, the system one and the recording one. The seam is real and the self-test uses it.

## Guide timing as a pure schedule in the Kit  [Strong, as part of M3]

Files: `Sources/UnnamedLauncher/Launcher.swift` (150 lines), `Sources/UnnamedLauncher/Guide.swift` (282 lines)
Signal: before a big feature. M3 adds the delay, the timeout and the error flash, and all three need a clock.

**Problem:** `Launcher.apply` turns effects straight into `guide.show` and `guide.hide`. Adding timers there would mix three clocks into the main-actor class that already owns permissions, capture and actions. It would also make the rules ("every key restarts the delay", "the timeout runs only while the Guide is visible") testable only by waiting in the self-test.

**Proposal:** a `GuideSchedule` value type in the Kit. It takes engine effects and timer fires with a time, and returns commands. `Launcher` arms one timer at `nextDeadline` and carries the commands out.

```swift
public struct GuideSchedule: Sendable {
    public init(runtime: Config.Runtime, ui: Config.UI)
    public mutating func handle(_ effect: SequenceEffect, at now: Double) -> [GuideCommand]
    public mutating func tick(at now: Double) -> [GuideCommand]
    public var nextDeadline: Double? { get }
}
public enum GuideCommand: Sendable, Equatable { case show(…), hide, flash, bell, endSequence }
```

**Benefits:** every M3 timing rule becomes a unit test with a fake clock, and `Launcher` stays a thin adapter. This isn't a behavior-preserving refactor; it's the shape S-016 is built in.

**Plan:** build it with S-016 to S-018 and S-021.

## `Guide.swift` split into the view and the panel  [Worth exploring]

`Guide.swift` holds `GuideContent`, `GuideView`, `GuidePanel` and `GuideController`. That's 282 lines, under the 600 line signal. Split it into `GuideView.swift` and `GuidePanel.swift` if M3's placement and theme code push it past about 400 lines.

## `SelfTest.swift` growing per story  [Speculative]

It's 197 lines, with one function per story area. Split it by milestone if it passes 400 lines.

## Top recommendation

**`GuideSchedule`, built as part of M3.** There's no Strong behavior-preserving refactor to do before M3.

## Considered, not recommended

- **Moving `SendShortcut`'s event building into the Kit.** It needs CoreGraphics event objects, and its rules (chord parsing, flags) are already split between the Kit tests and the self-test.
