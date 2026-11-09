# Unnamed Launcher: behavior and config spec

This is the source of truth for how sequences, actions and the config file behave. [BRIEF.md](BRIEF.md) says what the app is, and this file says how it works.

## How it works

### Bindings form a tree
- **Each config has one or more leaders.** A leader is a global chord, such as Hyper+Space, and opens a top-level menu.
- **Every entry is either a menu or a binding.** A menu has children and no action. A binding has an action and no children. A leader is always a menu.
- **Each key press is decided as soon as it arrives.** Which entry a key selects never depends on a timer, so there are no ambiguous prefixes.
- **There's no depth limit.** Two or three levels below the leader is typical.
- **Children are listed in config file order**, so you choose the order. The Bindings window has a "Sort Alphabetically" command for a menu. It rewrites that menu's children in three groups: named keys such as `Space` and `Tab` alphabetically (F-keys by number), then digits, then letters.

### During a sequence
| Key | Result |
| --- | --- |
| Leader chord | Opens its menu. The leader is consumed, so the app in front never sees it. |
| A child menu's key | Opens that menu. |
| A child binding's key | Runs the action and ends the sequence. |
| Back (default Backspace) | Goes to the parent menu, or ends the sequence when already in a leader's menu. |
| Cancel (default Escape) | Ends the sequence and runs nothing. |
| Any other key | Error feedback: the HUD flashes and/or the alert sound plays. The sequence stays where it is, and if the HUD was waiting for its delay, it appears now. |

- **Every key is consumed until the sequence ends.** That includes repeats and the key-ups of consumed keys. Outside a sequence, only leader chords are consumed.
- **Step keys have no modifiers.** Modifiers that belong to the leader and are still held are ignored, so you can press Hyper+W then 1 whether or not you've let go of Hyper. A step pressed with any other modifier doesn't match.
- **Keys mean physical positions on the US ANSI layout.** Other keyboard layouts don't change which key a name refers to.

### HUD
- **Delay:** `hudDelayMs` (default 0) is how long the sequence must sit idle before the HUD appears. Every key press restarts the delay. Once the HUD is shown, it stays until the sequence ends. If you know the sequence, nothing appears on screen.
- **Timeout:** `timeoutMs` (default 0, meaning off) ends the sequence after that long with the HUD visible and no key pressed. The timeout doesn't run while the HUD is still waiting for its delay, or when `showHud` is false.
- **Contents:** the HUD shows breadcrumbs (leader › menu › …) and the available keys with their titles. Contextual bindings that don't apply to the app in front are shown disabled.
- **Placement:** on the display of the app in front, at `position` (center, top or bottom).
- **Focus:** the HUD is a non-activating panel that never becomes the key window, so the app that was in front when the leader was pressed stays in front.

### Actions
| Type | Fields | Behavior |
| --- | --- | --- |
| `application` | `bundleId` | Brings the app forward if it's running, otherwise launches it. |
| `open` | `target` | Opens a file, folder or URL with its default app. A leading `~` expands to the home folder. |
| `exec` | `command` (array), optional `cwd`, `env` | Runs a process directly, with no shell and no expansion except a leading `~`. `cwd` defaults to the home folder. The app doesn't wait for it or capture its output, but does report if it fails to start. |
| `send` | `keys` | Sends one or more chords to the app that was in front. Held leader modifiers must not leak into the chord. `Primary` means ⌘. |
| `contextual` | `variants` (context id → action), optional `fallback` | Uses the first context, in config order, that matches the app in front and has a variant. If none matches, uses `fallback`. With no fallback, the action is unavailable. |
| `noop` | none | Does nothing. |

When an action fails, for example because the app isn't installed or the command can't start, the sequence ends and the failure is shown in the HUD and the log.

### Permissions and lifecycle
- **Required permissions:** Accessibility and Input Monitoring. Without both, the app installs no event tap, its menu bar icon shows a warning, and the menu names the missing permission with a button that opens the right pane in System Settings. If macOS needs a relaunch before a new grant takes effect, the menu offers one.
- **Event tap:** a session-level `CGEventTap`. The callback decides synchronously and must never block. If macOS turns the tap off, the app turns it back on and logs that it happened.
- **Secure Event Input:** while it's on, for example in a password field, keys don't arrive. The menu bar menu says so when it can detect it.
- **Disable:** turning the app off from the menu bar removes the tap, so no keys are captured.

## Config file

`~/.config/unnamed-launcher/config.json`. A dotfiles tool such as chezmoi may write this file and overwrite edits made in the app, which is fine. The app watches the file and reloads it when it changes. A reload with errors keeps the last valid config and reports the error. The Bindings window and Settings write the same file with keys in a stable order.

```json
{
  "version": 1,
  "runtime": { "cancelKey": "Escape", "backKey": "Backspace", "showHud": true, "hudDelayMs": 500, "timeoutMs": 5000 },
  "ui": { "theme": "system", "position": "center", "errorFlash": true, "errorBell": true },
  "entries": [
    { "keys": "Hyper+Space", "title": "Commands" },
    { "keys": "Hyper+Space E", "title": "Editor", "action": "open-editor" },
    { "keys": "Hyper+Space A", "title": "Applications" },
    { "keys": "Hyper+Space A T", "title": "Terminal", "action": "open-terminal" },
    { "keys": "Hyper+Space F", "title": "Find", "action": "search" }
  ],
  "actions": {
    "open-editor":   { "type": "application", "bundleId": "dev.zed.Zed" },
    "open-terminal": { "type": "application", "bundleId": "com.mitchellh.ghostty" },
    "search": {
      "type": "contextual",
      "variants": { "browser": { "type": "send", "keys": "Primary+L" } },
      "fallback": { "type": "send", "keys": "Primary+F" }
    }
  },
  "contexts": [
    { "id": "browser", "apps": ["com.google.Chrome", "org.mozilla.firefox"] }
  ]
}
```

- **Entries are a flat, ordered list keyed by their full path.** Each entry can be read and diffed on its own, duplicates and orphans are easy to report, and every depth uses the same shape.
- **Key syntax:** tokens are separated by spaces. The first token is a chord, `Mod+…+Key`. Modifiers are `Ctrl`, `Alt` (⌥), `Shift`, `Cmd`, `Primary` (⌘) and `Hyper` (⌃⌥⇧⌘). Names are case-insensitive.
- **Key names:** `A`–`Z`, `0`–`9`, `F1`–`F24`, `Space`, `Tab`, `Enter`, `Backspace`, `Delete`, `Escape`, the arrows, `Home`, `End`, `PageUp`, `PageDown`, `Grave`, `Minus`, `Equal`, `LeftBracket`, `RightBracket`, `Backslash`, `Semicolon`, `Quote`, `Comma`, `Period`, `Slash`.
- **Defaults:** only `version` and at least one entry are required. Everything else has a default.
- **Why JSON:** `Codable` reads and writes it with no dependency, arrays keep their order, and a JSON Schema gives editors validation. The app writes `config.schema.json` next to the config at launch, and the starter config's `"$schema": "./config.schema.json"` line points at it. The cost is that JSON has no comments.

### Validation
A config is rejected if any of these are true:
- `version` is missing or unsupported.
- There's an unknown field, a missing `title`, or `keys` that can't be parsed.
- Two entries have the same path (compared case-insensitively).
- An entry has no parent entry, or its parent is a binding.
- A leader is a binding, or a menu has no children.
- A step key has modifiers, or is the cancel or back key.
- The cancel and back keys are the same.
- A delay is negative.
- A binding names an undefined action.
- An action has the wrong fields for its type.
- A variant names an undefined context or is itself contextual.
- Two contexts share an `id`.

Actions or contexts that nothing uses produce a warning, not an error.

## Gotchas
- **The event tap callback must stay fast.** macOS turns off slow taps. The sequence engine has to be a small pure state machine (key events and timer fires in, decisions out) that has no AppKit dependency and can be fully unit-tested.
- **Held leader modifiers leak into `send`.** When sending a chord, set its flags explicitly rather than inheriting the current modifier state.
- **The HUD must never take focus.** Use an `NSPanel` with `.nonactivatingPanel` that doesn't become key. Keys come from the tap, not from the panel.
