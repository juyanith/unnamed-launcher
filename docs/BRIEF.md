# Unnamed Launcher

A native macOS leader-key launcher for one keyboard-first user. You press a leader chord, then one key per menu level, to open apps, files and URLs, run commands, or send shortcuts. If you pause, a HUD shows the options.

App name `UnnamedLauncher`, bundle id `net.unnamed.launcher`, project folder `unnamed-launcher`. Behavior and the config format are defined in [SPEC.md](SPEC.md).

## Replaces
Sol, which is used only to launch apps. Spotlight still handles search, and paneru still handles window management.

## Main jobs
1. **Run a binding by key sequence.** For example Hyper+Space → E opens the editor. If you finish the sequence quickly, nothing appears on screen. If you pause, the HUD shows breadcrumbs and the next options. The app in front never loses focus.
2. **See and edit bindings in the Bindings window.** It shows the menus and bindings as a tree, records chords and step keys, reorders a menu's items (by drag, or Sort Alphabetically), and edits actions and contexts. Every change is written back to the config file.
3. **Check status from the menu bar.** Turn the app on or off, reload the config, open the file, see the permission status with links to System Settings, see the last error, and quit.

## Data
The source of truth is one JSON file, `~/.config/unnamed-launcher/config.json`. The app watches it and reloads it when it changes. A dotfiles tool such as chezmoi may write it too. Format and file name were decided by the agent.
- **Entry:** `keys` (the leader chord and step keys), `title`, optional `action`. An entry with an action is a binding; one without is a menu.
- **Action:** `id`, `type` (`application`, `open`, `exec`, `send`, `contextual`, `noop`), and the fields for that type.
- **Context:** `id`, `apps` (bundle ids).
- **Settings:** `runtime` (cancel and back keys, HUD on or off, HUD delay, timeout) and `ui` (theme, position, error flash, error bell).

## Shape
A menu bar app with no Dock icon. It has four surfaces: a non-activating HUD panel that never becomes key, a menu bar menu, a Bindings window with a sidebar (Bindings, Actions, Contexts), and a small Settings window (⌘,) for the Guide, keys, feedback and Open at Login. See [DESIGN.md](DESIGN.md). macOS 27 or later. Swift and SwiftUI only, Mac only. Local data, works offline, no accounts.

## System hooks
- An active session-level `CGEventTap` captures leader chords and consumes every key during a sequence. It needs **Accessibility** and **Input Monitoring**, and the app does not run without them.
- Actions use `NSWorkspace` (application, open), `Process` with no shell (exec), and `CGEventPost` (send).
- Login item via `SMAppService`. Secure Event Input is reported in the menu bar menu.
- Not sandboxed. It is distributed with Developer ID and notarized, because event taps and synthetic key events don't fit the sandbox (research decision 6).

## Reference
None to clone. The HUD idea is close to which-key style leader menus.

## Look
Native, with the system accent color. The HUD is a small Liquid Glass panel, the Bindings window is a standard macOS 27 sidebar window, and Settings is a standard single-pane Settings window.

## Not in version one
- App or file search, clipboard history and window management. Spotlight and paneru already cover them.
- A Windows version.
- Sync, accounts, extensions and AI.
