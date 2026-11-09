# Architecture review, end of M5 (2026-11-08)

Survey: 5,665 lines. M5 added `ConfigSchema` to the Kit, built from `KeyName` and the action types so it can't drift, plus the Secure Input check in `Launcher`. No file except `SelfTest.swift` is over 280 lines.

## `SelfTest.swift` split by area  [Strong]  Done

Files: `Sources/UnnamedLauncher/SelfTest.swift` (420 lines)
Signal: a type over 400 lines that grows with every story, with M6 about to add more.

**Proposal:** keep the runner, `check` and `finish` in `SelfTest.swift`, and move the checks into extensions:
- `SelfTest+Launcher.swift`: M1 to M3, meaning the config, the Guide, actions and failures.
- `SelfTest+Editing.swift`: M4.
- `SelfTest+System.swift`: M5 and M6.

**Proof of same behavior:** the sorted PASS and FAIL lines from `tools/selftest.sh` are identical before and after (76 checks).

## Considered, not recommended

- **Moving the self-test into its own target.** It drives the real app objects (the Guide panel, the store, the editor), so it needs to stay in the app target, and it refuses to run without a `/tmp` config.

## Top recommendation

**The split, done in one commit.**
