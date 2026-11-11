# Architecture review, end of M8 (2026-11-11)

M8 added icons to the Guide: apps (S-054), files, folders and URLs (S-055), an `icon` of your own (S-056), and the app's glyph on menus and in the menu bar. Since M6, Help (S-051 to S-053) also landed.

**Size.** 7,345 lines of Swift. The largest file is `ConfigDocument.swift` at 321 lines, and no type is over 400 lines, so no file is near the 600-line signal.

**Most-changed files.**
- The test hooks again: `SelfTest` (22 commits) and `Snapshot` (20).
- `Launcher` (15), the one place that ties the parts together.

**Seams.** These hold, and dependencies still point one way, from the app to the Kit:
- `ConfigLocation`, through `APP_STORE`.
- `Launcher.start(captureKeys:seed:)`.
- `KeyEvent` into the pure `SequenceEngine`.
- `ActionPerformer`, with its system and recording adapters.
- `ConfigStore` as the one owner of the file.

**Fix log.** No area shows up three times.

## One home for Guide icons  [Strong]

Files:
- `Sources/UnnamedLauncherKit/ContextResolver.swift`: `IconSource` and `iconSource(_:)`, 60 lines that have nothing to do with contexts.
- `Sources/UnnamedLauncher/GuideIcons.swift`: the cache and lookups.
- `Sources/UnnamedLauncher/Guide.swift`: `appIcon(_:)`, three ways to draw an icon.
- `Sources/UnnamedLauncher/EntryEditor.swift`: `IconPreview`, a second copy of that drawing.
- `Sources/UnnamedLauncher/MenuBarMenu.swift`: `MenuBarIcon.glyph(side:)`, which the Guide's cache calls into.

Signal: one feature touched 6 files in 2 targets, and the drawing exists as two copies that have already drifted:
- The Guide draws from the cache. The editor's preview calls `NSWorkspace` on every redraw.
- The Guide handles `.menu`. The preview can't, so a menu's preview is blank.

Problem: changing how an icon looks means editing the Guide and the editor in step. For example, symbols at a different scale, or a dimmed glyph. Finding the rules for which icon an entry gets means reading `ContextResolver.swift`.

Proposal:

```swift
// UnnamedLauncherKit/Icons.swift: IconSource, IconSource(_:home:), and
// LoadedConfig.iconSource(_:) / iconSources(), moved from ContextResolver.swift.

// UnnamedLauncher/UI/EntryIcon.swift
/// An entry's icon as the Guide and the Bindings editor draw it: symbols and
/// the glyph in secondary, app and file icons in color, or empty space.
struct EntryIcon: View {
    let source: IconSource?
    var body: some View { … }   // reads GuideIcons.shared, loading on a miss off the Guide path
}
```

- The glyph's drawing moves from `MenuBarIcon` to a small `AppGlyph` enum in `UI/`. The menu bar and `GuideIcons` both use it, so the Guide no longer depends on the menu bar.
- `IconPreview` and `appIcon(_:)` both become `EntryIcon(source:)`.

Benefits:
- **Locality:** one view decides how an icon looks, and one Kit file decides which icon an entry gets.
- The preview gets the cache, and the `.menu` case, for free.
- `ContextResolver.swift` is about contexts again.

Proof of same behavior:
- The `IconTests` unit tests and the S-054 to S-056 self-test checks pass unchanged.
- The `hud-*`, `hud-home-*`, `bindings-icon-*` and `menubar-icons` snapshots match before and after.

Plan:
1. Move `IconSource` and the icon rules to `Kit/Icons.swift`. This is a pure move.
2. Add `AppGlyph`, and point the menu bar and `GuideIcons` at it.
3. Add `EntryIcon`, and switch the Guide and the editor to it. Delete `IconPreview`.

## `Launcher` split into capture and session  [Worth exploring]

This is carried over from M6, unchanged: `KeyboardAccess` for permissions, Secure Input, the tap and Enabled, and `SequenceSession` for the engine, the schedule and the Guide. `Launcher` is 205 lines. M8 added only one line to it, the icon load in `onLoad`. Do the split before the next feature that needs both halves, such as double-tap modifier leaders.

## Snapshot pages from a table  [Speculative]

This is carried over from M6. `Snapshot.swift` is now 233 lines, and M8 added two captures (`actions-help` and `bindings-icon`) in the same repeated "light and dark, set up, wait, capture" shape. It still works, and only agents read it.

## Considered, not recommended

- **Looking up icons off the main thread.** The lookups run once per config load: a dozen `NSWorkspace` calls, each well under a millisecond. Opening the Guide never waits on them.
- **Validating `icon` in the Kit's validator.** SF Symbol names can only be checked with AppKit. The editor's message and the empty space in the Guide are enough. A config warning would mean the Kit asking the app.
- **Self-test and snapshot code out of the app target.** They need the running app, its windows and its permissions, and the guards on `APP_STORE` keep them off the real config.

## Top recommendation

**One home for Guide icons**, in three small commits. It removes the copy that has already drifted, before more icon work lands on two places.
