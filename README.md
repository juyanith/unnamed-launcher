# Unnamed Launcher

A leader-key launcher for macOS that lives in the menu bar. Press a leader chord such as Hyper+Space, then one key per menu level, to open apps, files and URLs, run commands, or send shortcuts to the app in front.

If you finish the sequence quickly, nothing appears on screen. If you pause, a small HUD shows where you are and which keys come next. The app in front never loses focus.

## Features

- **Leader chords and menus.** Bindings form a tree with as many levels as you need. Back (Backspace) goes up a level and Cancel (Escape) ends the sequence.
- **Actions:**
  - **Use Application** focuses an app, starts it, or does whichever fits (the default). Focusing returns to the app's last focused window.
  - **Open** opens a file, folder or URL.
  - **Run Command** runs a process directly, with no shell.
  - **Send Shortcut** sends key chords to the app in front.
  - **Context Aware** picks a different action depending on which app is in front.
  - **Do Nothing.**
- **A Bindings window** to edit menus, bindings, actions and contexts, record chords, and reorder items.
- **One JSON config file** at `~/.config/unnamed-launcher/config.json`. The app watches it and reloads it when it changes, so you can keep it in your dotfiles. A config with errors is reported, and the last valid one stays in use.
- **A menu bar menu** to turn the launcher on or off, reload the config, check permissions, and see the last error.

## Requirements

- macOS 27 or later.
- Swift 6.2 or later (the Xcode 27 command line tools).
- **Accessibility** and **Input Monitoring** permissions. The launcher reads keys through an event tap and doesn't capture anything until both are granted. The menu bar menu links to the right pane in System Settings.

## Build and install

```sh
./build.sh --open
```

This builds a release version, signs it (with your Apple Development certificate if you have one, otherwise ad hoc), installs it to `~/Applications/UnnamedLauncher.app` and opens it. Build products go to `~/Library/Developer/UnnamedLauncher`, outside the repo.

With an ad hoc signature, macOS may ask for the permissions again after each rebuild.

## Config

On first launch the app writes a starter config. A small example:

```json
{
  "version": 1,
  "entries": [
    { "keys": "Hyper+Space", "title": "Commands" },
    { "keys": "Hyper+Space E", "title": "Editor", "action": "open-editor" },
    { "keys": "Hyper+Space F", "title": "Find", "action": "search" }
  ],
  "actions": {
    "open-editor": { "type": "application", "bundleId": "dev.zed.Zed" },
    "search": {
      "type": "contextual",
      "variants": { "browser": { "type": "send", "keys": "Primary+L" } },
      "fallback": { "type": "send", "keys": "Primary+F" }
    }
  },
  "contexts": [
    { "id": "browser", "apps": ["com.google.Chrome", "com.apple.Safari"] }
  ]
}
```

An entry with an `action` is a binding, and one without is a menu. The full format, including runtime and HUD settings, is in [docs/SPEC.md](docs/SPEC.md).

## Development

```sh
swift test --scratch-path ~/Library/Developer/UnnamedLauncher/test-build   # unit tests
tools/selftest.sh                                                          # the app's own checks, against a /tmp config
tools/snap.sh                                                              # light and dark snapshots of every page
```

- `Sources/UnnamedLauncher/` is the app. `Sources/UnnamedLauncherKit/` holds the rules and config logic, with no UI, and has the unit tests.
- [ARCHITECTURE.md](ARCHITECTURE.md) covers the targets, threads and seams.
- [docs/](docs/) has the brief, the spec, the stories, the glossary and the design notes.
