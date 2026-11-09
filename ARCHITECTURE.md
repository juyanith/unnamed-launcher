# Architecture

## Targets

| Target | Holds | Depends on |
| --- | --- | --- |
| `UnnamedLauncherKit` | Pure logic: key names and chords (`Keys.swift`), the config model with strict decoding (`Config.swift`), validation and the binding tree (`ConfigValidator.swift`), loading and the starter config (`ConfigLoader.swift`), the sequence engine (`SequenceEngine.swift`). There's no AppKit and no default actor isolation, and everything is `Sendable`. | Foundation |
| `UnnamedLauncher` | The app: menu bar menu, Bindings window, Settings, the Guide panel, the event tap, actions, permissions. Main-actor by default. | `UnnamedLauncherKit`, AppKit, SwiftUI |
| `UnnamedLauncherKitTests` | Unit tests for every validation rule and engine rule. | `UnnamedLauncherKit` |

Dependencies point one way: the app depends on the Kit, and the Kit depends on nothing of ours.

## Runtime

```text
tap thread                                   main thread
──────────                                   ───────────
CGEvent tap ─► TapContext ─► EngineBox ──┐
   (KeyCapture, TapLoop)    (Mutex around │
                             SequenceEngine)
                 consume / pass ◄─────────┤
                                          └─ DispatchQueue.main ─► Launcher.apply(effect)
                                                                     ├─ GuideController (show, hide)
                                                                     └─ ActionRunner (Open App, …)
ConfigStore (main) ── onLoad ─► EngineBox.replace(config)
```

- **The event tap runs on its own thread** (`net.unnamed.launcher.event-tap`, user-interactive). The callback decides consume or pass at once, from the engine alone. A busy main thread never delays a keystroke.
- **Effects reach the main queue in order:** show the Guide, run an action, cancel, or an unbound-key error.
- **`ConfigStore` loads and validates on the main thread.** A valid config replaces the engine's config under the lock. A reload with errors keeps the last valid one.
- **`Launcher` owns permissions, Enabled, the tap, the engine box and the Guide.** The menu bar menu reads its state through `MenuBarStatus`, a plain value the self-test checks.

## Seams

| Seam | Adapters | Test use |
| --- | --- | --- |
| `ConfigLocation` (`APP_STORE`) | the real `~/.config/unnamed-launcher/config.json`; a file in `/tmp` | The self-test and snapshots never touch the real config |
| `Launcher.start(captureKeys:)` | the real tap; no tap | Snapshots and the self-test never capture the keyboard |
| `KeyEvent` into `SequenceEngine` | the event tap; unit tests | Every sequence rule is tested without a keyboard |

Planned in M2: an `ActionPerformer` seam for open, launch, spawn and post-events, so the self-test can check actions without running them. See `docs/architecture-review-2026-11-08.md`.

## Reviews

- [docs/architecture-review-2026-11-08.md](docs/architecture-review-2026-11-08.md) (end of M1)
