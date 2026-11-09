# Unnamed Launcher: stories

Built from [BRIEF.md](BRIEF.md), [SPEC.md](SPEC.md) and [research/launchers.md](research/launchers.md). There is no reference app, so `Screens:` names the snapshot pages that show each story.

**Snapshot pages:**

| Page | Shows |
| --- | --- |
| `hud` | The HUD over a sample app |
| `hud-error` | The HUD after an unbound key or a failed action |
| `menubar` | The menu bar menu, all OK |
| `menubar-warning` | The menu bar menu with a missing permission or a config error |
| `welcome` | The first-run window |
| `settings-bindings` | The Bindings page of the settings window |
| `settings-actions` | The Actions page |
| `settings-contexts` | The Contexts page |
| `settings-general` | The General page |

**How each acceptance line is checked:** `[snap]` snapshot, `[unit]` unit test, `[self]` self-test, `[manual]` a person must try it.

**Seed data:** snapshot mode loads a fixture config with two leaders, a nested menu, actions of every type, and two contexts. Each of these can be created in the settings window (S-024 to S-032).

---

## M1 Core loop

Press a leader, step through a menu from the config file, and launch an app. You can use it for a day by editing the JSON by hand.

### S-001 Load and check the config file
As the user, I write `~/.config/unnamed-launcher/config.json` and the app loads it when it launches.
Screens: menubar
Acceptance:
- [unit] Every rule in SPEC.md Validation rejects a config with a message naming the entry or action and the rule. Unused actions and contexts give warnings.
- [unit] A config that has only `version` and one leader with one binding loads, with every setting at its default.
- [unit] Entry order is kept exactly as in the file.
- [self] If no file exists, the app writes a starter config with one leader (Hyper+Space) and two example bindings, then loads it.
UX:
- Flow: launch the app, which reads the config file → if the file is missing, writes the starter config → the menu bar icon shows Ready. There's nothing to undo, and the starter file is never written over an existing file.
- Surface: none of its own. The status appears in the menu bar menu (S-008).
- States: missing file → starter written, and the menu shows "Created config file" once. Invalid file → error state (S-008). Valid → Ready.
- Words: the starter has the leader "Commands" (Hyper+Space) with bindings "Finder" (F, Open App) and "Terminal" (T, Open App, `com.apple.Terminal`). Errors name the path and the rule in one sentence, such as "Binding “Hyper+Space Q” uses action “open-foo”, which isn't defined." No codes, no blame.
- Access: n/a.
Status: todo

### S-002 Grant the permissions the app needs
As the user, I see which permission is missing in the menu bar menu and click to open the right System Settings pane.
Screens: menubar-warning, menubar
Depends: S-001
Acceptance:
- [snap] With Accessibility or Input Monitoring missing, the menu bar icon shows a warning badge and the menu lists each missing permission with an "Open System Settings…" item.
- [self] With a permission missing, no event tap is installed.
- [manual] After you grant both, keys are captured without relaunching. If macOS requires a relaunch, the menu offers "Relaunch to Finish Setup".
UX:
- Flow: click the menu bar icon (with its warning badge) → the menu lists each missing permission → "Open Accessibility Settings…" opens that pane → you turn the app on and come back → the app re-checks when the menu opens and when it becomes active, the row disappears, and capture starts. Way back: closing System Settings changes nothing.
- Surface: menu bar menu rows (inline: a status the user acts on right where it's shown). There's no alert. A missing permission isn't urgent enough to interrupt, and the welcome window (S-040) comes later.
- States: both missing → two rows. One missing → one row. Both granted → no rows, and the icon is normal. Granted but macOS still blocks it → "Relaunch to Finish Setup".
- Words: a section header "Needs Permission", then rows "Accessibility — Open Settings…" and "Input Monitoring — Open Settings…". Under them, a disabled line in sentence case: "Unnamed Launcher needs both to capture your leader keys."
- Access: the menu is fully keyboard-operable as a standard NSMenu. The warning badge is also announced: the status item's accessibility label is "Unnamed Launcher, needs permission".
Status: todo

### S-003 Start a sequence with a leader chord
As the user, I press Hyper+Space anywhere and the launcher takes over the keyboard until the sequence ends.
Depends: S-001, S-002
Acceptance:
- [unit] When idle, the engine consumes only leader chords. Every other event passes through.
- [unit] Once a sequence starts, every key-down, repeat and matching key-up is consumed.
- [self] The tap callback returns in under 1 ms for 1,000 synthetic events.
- [manual] The app in front never sees the leader. For example, Hyper+Space in a text field types nothing.
Status: todo

### S-004 Step through menus with single keys
As the user, I press A then T after the leader to reach Applications › Terminal.
Depends: S-003
Acceptance:
- [unit] A child menu's key opens that menu, and a child binding's key ends the sequence with that binding.
- [unit] Leader modifiers that are still held are ignored on step keys. Any other modifier makes the step not match.
- [unit] Keys match by physical position (US ANSI), whatever the active layout.
- [unit] Menus can nest without limit. A test with 6 levels passes.
Status: todo

### S-005 See the options in the HUD
As the user, I see a small panel showing where I am and which keys I can press next.
Screens: hud
Depends: S-004
Acceptance:
- [snap] The HUD shows breadcrumbs ("Commands › Applications") and one row per child, in file order: the key in a keycap, the title, and a › on rows that open a menu.
- [snap] Light and dark versions both read clearly over a busy background.
- [manual] The app that was in front stays active, keeps its focus ring and caret, and gets no keys while the HUD is up.
- [self] The HUD panel never becomes the key window.
UX:
- Flow: press the leader → the guide appears (after the delay, S-016) → press a key → the guide updates in the same frame, or closes when a binding runs. Escape cancels and Backspace goes back (S-007).
- Surface: Panel (a tool kept open beside the work that you watch while you type). It's a non-activating, floating, borderless Liquid Glass panel with no title or close button.
- States: normal (path plus rows). Too many rows → two columns after 12 rows; past 24, three columns. Long titles truncate at the end, and the full title is spoken by VoiceOver. A Choose by App binding with no match is dimmed and its row reads "not available in <App>" (S-013). An empty menu can't happen because validation blocks it.
- Words: the path uses the menu titles joined with " › ", starting with the leader's title, for example "Commands › Applications". Each row shows a keycap (key name: "E", "Space", "F5"), the title, and a trailing "›" if it opens a menu. The footer shows the keycaps "esc Cancel" and "⌫ Back" in secondary text.
- Access: keys come from the event tap, so the guide needs no focus. VoiceOver announces the path when the guide opens and each menu change ("Applications, 3 keys") through an accessibility notification, without moving VoiceOver focus. Keycaps are not color-only. Text is at least 11 pt, and the guide follows Increase Contrast. Reduce Motion turns the appear animation into a fade.
Status: todo

### S-006 Open or switch to an app with a binding
As the user, I press Hyper+Space E and Zed comes to the front, launching first if it isn't running.
Depends: S-004
Acceptance:
- [self] When the app is running, it's activated. When it isn't, `NSWorkspace` launches it by `bundleId`.
- [self] When the bundle id isn't installed, the sequence ends and the failure is recorded (shown in S-015).
- [manual] From the leader press to the app activating takes under 100 ms when the app is already running.
Status: todo

### S-007 Cancel or go back mid-sequence
As the user, I press Escape to stop, or Backspace to go up one menu.
Depends: S-005
Acceptance:
- [unit] Cancel ends the sequence without running anything, from any depth.
- [unit] Back goes to the parent menu. In a leader's own menu, it ends the sequence.
- [snap] After Back, the HUD shows the parent menu's breadcrumbs and rows.
UX:
- Flow: during a sequence, Escape → the guide fades out and nothing runs. Backspace → the guide shows the parent menu, and Backspace in the leader's own menu cancels.
- Surface: the guide (S-005).
- States: when the sequence ends with no visible guide (it was still waiting for its delay), nothing appears. The feedback is simply that the next key types normally.
- Words: the footer keycaps "esc Cancel" and "⌫ Back" show the configured keys by name. When Back is turned off, the Back keycap is hidden.
- Access: VoiceOver announces "Cancelled" on Cancel and the parent menu's name on Back.
Status: todo

### S-008 Reload the config and see its errors
As the user, I choose "Reload Config" or "Open Config File" in the menu bar, and if the file is broken I see why.
Screens: menubar, menubar-warning
Depends: S-001
Acceptance:
- [unit] A reload with errors keeps the last valid config running.
- [snap] With an error, the menu shows the first error with its entry path, and the icon shows a warning badge.
- [self] "Open Config File" opens the file in the default JSON editor.
UX:
- Flow: menu bar icon → "Reload Config" (⌘R in the menu) → valid: the menu closes, and the next open shows "Config loaded at 14:02". Invalid: the icon gets its warning badge, and the menu shows the error with "Open Config File". Way back: the last valid config keeps running, so nothing breaks.
- Surface: menu bar menu rows (inline). Never an alert, because a broken file doesn't stop the app working.
- States: OK → a disabled line "Config loaded at 14:02". Error → a section "Config Error" with the first error in sentence case, wrapped to 2 lines with the full text in a tooltip, plus "+2 more" if there are more. Warnings (unused actions) never show in the menu, only in Settings (S-034) and the log.
- Words: "Reload Config", "Open Config File", "Show in Finder" (with ⌥ held), and "Config Error" as the section header. Errors follow S-001's pattern.
- Access: standard NSMenu. The error line is a disabled item, so VoiceOver reads it in order.
Status: todo

### S-009 Turn the launcher off and on, or quit
As the user, I uncheck "Enabled" in the menu bar menu so no keys are captured, or choose Quit.
Screens: menubar
Depends: S-003
Acceptance:
- [self] When disabled, the event tap is removed. Turning it back on reinstalls the tap.
- [snap] When disabled, the menu bar icon is dimmed.
- [self] Quit removes the tap before the app exits.
UX:
- Flow: menu bar icon → "Enabled" (a check mark that toggles) → the icon dims and leaders type normally again → choose it again to turn it back on. "Quit Unnamed Launcher" (⌘Q) quits with no confirmation, since nothing is lost.
- Surface: menu bar menu, a toggle item (inline: changes one value).
- States: on → check mark, normal icon. Off → no check mark, dimmed icon, and the status line reads "Not capturing leaders". Enabled is remembered across launches.
- Words: menu order is the status line, "Enabled", a separator, "Reload Config", "Open Config File", a separator, "Settings…" (⌘,), "Quit Unnamed Launcher" (⌘Q).
- Access: the status item's accessibility label includes the state: "Unnamed Launcher, off".
Status: todo

## M2 Actions

### S-010 Open a file, folder or URL
As the user, I bind a key to `~/notes` or `https://…` and it opens in its default app.
Depends: S-006
Acceptance:
- [unit] A leading `~` expands to the home folder, and nothing else is expanded.
- [self] File URLs and web URLs both open through `NSWorkspace`.
Status: todo

### S-011 Run a command
As the user, I bind a key to `["zed", "~/notes"]` and it runs with no shell.
Depends: S-006
Acceptance:
- [unit] Arguments are passed literally. Only a leading `~` in `command` and `cwd` is expanded.
- [self] `cwd` defaults to the home folder, and `env` is added to the inherited environment.
- [self] A program that can't be found ends the sequence with a failure, and the app doesn't wait for a program that does start.
Status: todo

### S-012 Send a shortcut to the app in front
As the user, I bind Hyper+F F to send ⌘F to the app I was using.
Depends: S-006
Acceptance:
- [unit] `send` parses one or more chords, and `Primary` maps to ⌘.
- [self] Sent events carry only the chord's own modifier flags, even while Hyper is still held.
- [manual] ⌘F reaches the app that was in front when the leader was pressed.
Status: todo

### S-013 Pick an action by the app in front
As the user, I bind one key that sends ⌘L in a browser and ⌘F everywhere else.
Screens: hud
Depends: S-012
Acceptance:
- [unit] The first context in `contexts` order that matches the front app's bundle id and has a variant wins. Otherwise `fallback` runs, and with no fallback the action is unavailable.
- [snap] In the HUD, a contextual binding that's unavailable for the front app shows as dimmed.
- [unit] Pressing an unavailable binding gives error feedback and runs nothing.
Status: todo

### S-014 Reserve a key with a no-op
As the user, I bind a key to `noop` to hold its place or show a note in the HUD.
Depends: S-004
Acceptance:
- [unit] A `noop` binding ends the sequence and does nothing else.
Status: todo

### S-015 See why an action failed
As the user, when an app isn't installed or a command can't start, the HUD tells me and the log records it.
Screens: hud-error
Depends: S-006
Acceptance:
- [snap] The HUD shows a red error line, such as "Couldn't open dev.zed.Zed: not installed", for 2 seconds, then closes.
- [self] Every failure is written to the unified log under subsystem `net.unnamed.launcher`.
Status: todo

## M3 Timing and feedback

### S-016 Finish a known sequence with nothing on screen
As the user, I set `hudDelayMs` to 500 and fast sequences never show the HUD.
Depends: S-005
Acceptance:
- [unit] The HUD shows only after the delay passes with no key press. Every key, including Back, restarts the delay.
- [unit] Once shown, the HUD stays until the sequence ends.
Status: todo

### S-017 Let an abandoned sequence time out
As the user, I set `timeoutMs` to 5000 and a forgotten HUD closes by itself.
Depends: S-016
Acceptance:
- [unit] The timeout runs only while the HUD is visible, and every key press restarts it.
- [unit] When `showHud` is false, the timeout never fires.
Status: todo

### S-018 Get feedback for a key that isn't bound
As the user, a wrong key flashes the HUD and beeps, and the sequence stays where it was.
Screens: hud-error
Depends: S-005
Acceptance:
- [unit] An unbound key leaves the state unchanged and emits an error decision.
- [snap] With `errorFlash` true, the HUD shows a flash state.
- [unit] With `errorBell` true, an error decision plays the system alert sound, and with it false, no sound plays.
- [unit] If the HUD was still waiting for its delay, it appears at once.
Status: todo

### S-019 Choose where the HUD appears
As the user, I set `position` to center, top or bottom on the display of the app I'm using.
Screens: hud
Depends: S-005
Acceptance:
- [self] The HUD appears on the screen that holds the front app's key window, not the main screen.
- [snap] Center, top and bottom positions each have a snapshot.
Status: todo

### S-020 Set the HUD theme
As the user, I set `theme` to system, light or dark.
Screens: hud
Depends: S-005
Acceptance:
- [snap] Light and dark snapshots both match the token colors, whatever the system appearance.
Status: todo

### S-021 Run sequences with no HUD at all
As the user, I set `showHud` to false and never see the panel.
Depends: S-016
Acceptance:
- [unit] With `showHud` false, sequences still resolve, errors still beep, and no panel is created.
Status: todo

### S-022 Choose my own cancel and back keys
As the user, I set `cancelKey` to Q and `backKey` to an empty string to turn Back off.
Depends: S-007
Acceptance:
- [unit] The configured keys work, an empty `backKey` turns Back off, and binding a step to either key fails validation.
Status: todo

## M4 Settings window

### S-023 See all bindings as a tree
As the user, I open Settings… from the menu bar and see every leader, menu and binding in an outline.
Screens: settings-bindings
Depends: S-001
Acceptance:
- [snap] A sidebar with Bindings, Actions, Contexts and General. Bindings shows an outline with key, title and action columns, in file order.
- [snap] An invalid config shows a banner above the outline listing the errors, and the outline shows the last valid config.
Status: todo

### S-024 Add a menu or binding
As the user, I select a menu and choose Add Binding or Add Menu (⌘N and ⇧⌘N).
Screens: settings-bindings
Depends: S-023, S-033
Acceptance:
- [self] The new entry is added at the end of the selected menu, with its key recorder focused.
- [unit] Saving an entry with no key, or a key that's already taken in that menu, is blocked and the reason is shown inline.
Status: todo

### S-025 Record a key
As the user, I click a key field and press the chord or key I want.
Screens: settings-bindings
Depends: S-024
Acceptance:
- [self] For a leader, the recorder captures a full chord. For a step, it captures one key with no modifiers.
- [unit] Recorded keys are stored in canonical form ("Hyper+Space", "A").
- [snap] A conflict with a sibling entry, or with the cancel or back key, is shown in red under the field.
Status: todo

### S-026 Edit a binding's title and action
As the user, I change a binding's title or pick a different action from a popup.
Screens: settings-bindings
Depends: S-024, S-030
Acceptance:
- [self] Changing the title or action rewrites only that entry in the file.
- [unit] The action popup lists every defined action, plus "New Action…".
Status: todo

### S-027 Delete an entry
As the user, I press Delete on a selected entry to remove it.
Screens: settings-bindings
Depends: S-023, S-033
Acceptance:
- [self] Deleting a menu that has children asks first and names how many entries will go. ⌘Z restores them.
Status: todo

### S-028 Reorder a menu's items by dragging
As the user, I drag a binding up or down within its menu.
Screens: settings-bindings
Depends: S-023, S-033
Acceptance:
- [self] The new order is written to the file, and the HUD then lists the items in that order.
- [self] An item can't be dropped into a different menu by dragging, because that would change its key path.
Status: todo

### S-029 Sort a menu alphabetically
As the user, I choose Sort Alphabetically on a menu.
Screens: settings-bindings
Depends: S-028
Acceptance:
- [unit] The children are sorted in three groups: named keys alphabetically with F-keys by number, then digits, then letters.
- [self] The command can be undone.
Status: todo

### S-030 Create and edit actions
As the user, I add an action, pick its type, and fill in a form for that type.
Screens: settings-actions
Depends: S-023, S-033
Acceptance:
- [snap] A list of actions with their type and how many bindings use each, plus a form that changes with the type.
- [self] For `application`, the bundle id comes from an app picker (an Open panel limited to apps) or is typed in.
- [self] Renaming an action id updates every binding that uses it. Deleting an action that's in use is blocked and lists its users.
Status: todo

### S-031 Define contexts
As the user, I create a "browser" context and add Chrome and Firefox to it.
Screens: settings-contexts
Depends: S-030
Acceptance:
- [snap] A list of contexts in order, each showing its apps with their icons and names.
- [self] Contexts can be reordered by dragging, and the order is saved because it decides which variant wins.
Status: todo

### S-032 Change general settings
As the user, I set the HUD delay, timeout, position, theme and feedback options in a form.
Screens: settings-general
Depends: S-023, S-033
Acceptance:
- [snap] A grouped form with each setting from `runtime` and `ui`, each with a short help line.
- [unit] A negative delay can't be entered.
Status: todo

### S-033 Save edits back to the config file
As the user, every change I make in the settings window is written to `config.json` right away.
Depends: S-001
Acceptance:
- [unit] A config loaded and saved with no edits keeps the same entry order, action order and contexts as the original.
- [unit] Output is pretty-printed with a stable key order, so edits make small diffs.
- [self] The write is atomic. A write that would produce an invalid config is refused, and the file isn't changed.
- [self] If the file changes on disk while the window is open, the window reloads it.
Status: todo

### S-034 Fix validation errors from the settings window
As the user, I click an error in the banner and the entry or action it names is selected.
Screens: settings-bindings
Depends: S-023
Acceptance:
- [self] Clicking an error selects the right row and focuses the field with the problem.
Status: todo

## M5 System

### S-035 Reload automatically when the file changes
As the user, I save the config in my editor, or chezmoi rewrites it, and the new bindings work at once.
Depends: S-008
Acceptance:
- [self] A change to the file, including an atomic replace (write to a temp file, then rename), triggers a reload within 1 second.
Status: todo

### S-036 Start at login
As the user, I turn on "Open at Login" in General.
Screens: settings-general
Depends: S-032
Acceptance:
- [self] The switch uses `SMAppService.mainApp` and reflects its current `status`. If you turn it off in System Settings, the switch shows off.
Status: todo

### S-037 Recover when macOS turns off the event tap
As the user, I never lose my leader keys because macOS paused the tap.
Depends: S-003
Acceptance:
- [self] On `tapDisabledByTimeout` or `tapDisabledByUserInput`, the tap is turned back on and the event is logged.
Status: todo

### S-038 Know when a password field is blocking keys
As the user, the menu bar tells me when Secure Event Input is on, so I know why the leader doesn't work.
Screens: menubar-warning
Depends: S-002
Acceptance:
- [snap] While `IsSecureEventInputEnabled()` is true, the menu shows "Keyboard is secured by another app" with a short explanation.
Status: todo

### S-039 Get editor help from a JSON Schema
As the user, my editor validates and autocompletes `config.json`.
Depends: S-001
Acceptance:
- [unit] `config.schema.json` accepts the fixture config and rejects one sample of each type error.
- [self] The starter config includes a `$schema` reference, and loading ignores the `$schema` field.
Status: todo

## M6 Polish

### S-040 Welcome on first launch
As the user, on first launch I see what the app does, which permissions it needs, and where the config file is.
Screens: welcome
Depends: S-002, S-001
Acceptance:
- [snap] A small window with three steps: grant Accessibility, grant Input Monitoring, try Hyper+Space. Each step shows a check mark once done.
- [self] It shows only until both permissions are granted and you've run one sequence.
Status: todo

### S-041 App icon and menu bar icon states
As the user, I can tell at a glance whether the launcher is ready, off, or needs attention.
Screens: menubar, menubar-warning, welcome
Acceptance:
- [snap] An app icon (Icon Composer, light, dark and tinted) and a template menu bar symbol with normal, dimmed and warning states.
Status: todo

### S-042 Empty states in the settings window
As the user, an empty page tells me what to add and how.
Screens: settings-bindings, settings-actions, settings-contexts
Depends: S-023
Acceptance:
- [snap] Each empty list shows one line of explanation and an Add button.
Status: todo

### S-043 Context menus in the outline
As the user, I right-click an entry to Add Binding Here, Duplicate, Sort Alphabetically or Delete.
Screens: settings-bindings
Depends: S-024, S-027, S-029
Acceptance:
- [self] Every context menu item matches an item in the menu bar, with the same name and shortcut.
Status: todo

### S-044 Use the settings window from the keyboard
As the user, I move through the outline with the arrow keys, press Return to edit a title, and press Space to record a key.
Screens: settings-bindings
Depends: S-025
Acceptance:
- [manual] Every action in the settings window can be done without a mouse.
- [self] VoiceOver reads each row as "key, title, action".
Status: todo

## Later
- Import and export a single menu as a JSON snippet.
- A Windows version that reads the same config.
- Double-tap modifier leaders, such as tapping ⌥ twice.
- Showing app icons in the HUD rows for `application` bindings.

## Dropped
Main jobs in the brief map to M1 (job 1), M4 (job 2) and S-002, S-008 and S-009 (job 3). Rows marked "Version one? Yes" in the research matrix were written before the scope changed to leader keys only:
- **App launch:** covered by S-006.
- **Fuzzy and initials matching:** dropped. There's no search, and keys are exact.
- **Ranking that learns from your choices:** dropped. Order is set by you (S-028).
- **File search:** dropped. Spotlight covers it.
- **Action panel on results (⌘K):** dropped. There are no results to act on.
- **Act on selection (Instant Send):** dropped for version one.
- **Aliases and quick keys:** dropped. Key sequences replace them.
- **Per-item global hotkey:** covered by multiple leaders (S-001, S-003).
- **Calculator and units:** dropped.
- **Web search and quicklinks:** covered by `open` with a URL (S-010).
- **System commands:** covered by `exec` and `send` (S-011, S-012).
- **Run scripts and Shortcuts:** covered by `exec`, for example `shortcuts run "Name"` (S-011).
- **Accounts, sync, analytics, upgrade prompts:** dropped. This is a personal app.
