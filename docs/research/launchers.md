# Mac keyboard launchers

Research for the unnamed launcher (app name not picked yet). Done 2026-11-08.
[V] verified in a source, [K] from knowledge, [U] unverified, test first.

**Question:** what makes the best keyboard launcher on the Mac?
**Decision it informs:** what goes in version one, and which macOS APIs and distribution route it uses.

> **Scope changed on 2026-11-08 (see ../BRIEF.md).** The app is now a leader-key launcher only, with no search. Decisions 1, 3, 5, 6, 7 and 9 and the platform table still apply. Decisions 2, 4, 8, 10 and 11 (search ranking, the action panel, app indexing, clipboard and pricing) do not. Decision 7 changes too: the app now uses a `CGEventTap` (Accessibility + Input Monitoring) rather than KeyboardShortcuts, because it must consume every key during a sequence.

## Findings

### Market
- **Spotlight on macOS 26 is now a launcher with actions.** ⌘3 filters to actions and Shortcuts, you fill in parameters inline, and actions can have typed quick keys. It also has clipboard history (30 min / 8 h / 7 days). [V](https://support.apple.com/guide/mac-help/mchl4953dfeb) [V](https://www.macrumors.com/how-to/do-more-with-spotlight-in-macos-tahoe/)
- **Build for macOS 27, not 26.** Apple's help page already covers 27, Alfred 5.8 shipped "Ready for macOS 27" on 2026-09-11, and this Mac runs 27.0.1. [V](https://www.alfredapp.com/blog/) [V, sw_vers]
- **Raycast gives its core launcher away free** (clipboard for 3 months, snippets, quicklinks, calculator, basic window management, extension store). It charges for AI credits, sync, themes and custom layouts: Pro $10/mo, Plus $20, Max $50. [V](https://www.raycast.com/pricing)
- **Raycast ships about weekly.** v2.7 to v2.11 came out between 2026-10-09 and 11-04, mostly AI features plus speed work. [V](https://www.raycast.com/changelog)
- **Raycast v2 rebuilt its interface in React inside WebKit views.** [V](https://raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)
- **Alfred 6 is announced for autumn 2026** with a native workflow UI, searchable query history, faster file search and better accessibility. The Powerpack is £34 (£59 with lifetime upgrades). [V](https://www.alfredapp.com/v6/?sneak2) [V](https://www.alfredapp.com/powerpack/)
- **LaunchBar 6** (6.22.2) learns abbreviations, browses and acts on files, and has Instant Send. The free version never expires but nags. Price not checked: the buy page returned 404. [V](https://www.obdev.at/products/launchbar/index.html) [U]
- **Quicksilver** is free and open source, built on plugins, and works by chaining an action onto an object. It has long been seen as "effectively dead". [V](https://qsapp.com/) [V](https://talk.macpowerusers.com/t/anyone-still-using-quicksilver/10199)
- **Sol** is MIT-licensed with about 3.2k stars, built on React Native, and bundles a launcher, window manager, clipboard and calendar. [V](https://github.com/ospfranco/sol)
- **Tinycast** is fully native with no account or telemetry. Sindre Sorhus moved to it from Raycast in Sep 2026. [V](https://talk.macpowerusers.com/t/sindre-sorhus-switched-from-raycast-to-tinycast/46944)

### How the leaders work
- **Raycast's ranking order:** exact alias match, then alias prefix match, fuzzy title, subtitle and keywords, then frecency (how often and how recently you chose a result for this query). Each item has a "Reset Ranking" action. [V](https://manual.raycast.com/search-bar)
- **Raycast's action panel** opens with ⌘K. ↵ runs the first action, and the panel is searchable with each action's shortcut shown. [V](https://manual.raycast.com/action-panel)
- **Raycast aliases and hotkeys:** aliases match exactly, and an alias plus a space jumps to the first argument. Any command can have its own global hotkey, and the recorder detects conflicts. [V](https://manual.raycast.com/command-aliases-and-hotkeys)
- **Alfred matching:** initials ("gc" finds Google Chrome) or fuzzy from word boundaries. It learns which result you pick for each query. Actions open with → in the panel and ⌘/ anywhere (Universal Actions). [V](https://www.alfredapp.com/help/features/default-results/) [V](https://www.alfredapp.com/help/features/universal-actions/)
- **LaunchBar abbreviation learning:** if a short abbreviation misses, it learns from the longer one you type next. [V](https://obdev.at/resources/launchbar/help/AbbreviationSearch.html)
- **LaunchBar Instant Send:** hold the hotkey to send the current selection into LaunchBar. [V](https://www.obdev.at/products/launchbar/features.html)
- **Panel position:** all three open the panel centred in the upper third of the screen. [K] Exact sizes are [U].

### Platform (this Mac and macOS APIs)
| Feature | API | Permission | Works in the sandbox? | Limits |
| --- | --- | --- | --- | --- |
| Global hotkey | KeyboardShortcuts library (wraps Carbon `RegisterEventHotKey`) | None | Yes [V](https://swiftpackageregistry.com/sindresorhus/KeyboardShortcuts) | Option-only combos fail since macOS 15 [V](https://developer.apple.com/forums/thread/763878?page=2). ⌘Space is taken by Spotlight on this Mac [V, PlistBuddy] |
| Double-tap modifier hotkey | `CGEventTap` | Input Monitoring | Unreliable [K] | Leave out of version one |
| Floating panel | `NSPanel` (`.nonactivatingPanel`, `.floating`, `canJoinAllSpaces`, `fullScreenAuxiliary`) | None | Yes [K] | Override `canBecomeKey`. Full screen and Stage Manager [U] |
| Find installed apps | `NSMetadataQuery` on `com.apple.application-bundle`, plus a fallback folder scan | None | Yes [K] | Scanning `/Applications` finds only 26 of 352 apps here [V, mdfind] |
| Open apps and files | `NSWorkspace.openApplication` / `open` | None | Partly [K] | Sandbox needs a security-scoped grant per file |
| File search | `NSMetadataQuery` / `MDQuery` | Full Disk Access for full coverage | Container and granted folders only [K] | Spotlight's index is unreliable on macOS 26 [V](https://talk.tidbits.com/t/spotlight-in-os-26-not-indexing-all-files/32065) |
| Icons | `NSWorkspace.icon(forFile:)` | None | Yes | Cache them, load off the main thread [K] |
| Clipboard history | Poll `NSPasteboard.changeCount` | Pasteboard privacy prompt possible | Yes [K] | [V](https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum/default.md). Behavior on macOS 27 [U]. Auto-paste needs Accessibility |
| Shortcuts | `shortcuts run` / `shortcuts://` | None | URL scheme yes, `Process` [U] | |
| Scripts and shell | `Process`, `NSUserAppleScriptTask` | Automation prompt per target app | Effectively no [K] | |
| Window management | Accessibility `AXUIElement` | Accessibility | No [V](https://developer.apple.com/forums/thread/810677) | No entitlement exists |
| Launch at login | `SMAppService.mainApp` | Shown in the user's Login Items | Yes | Check `status` first [V](https://developer.apple.com/forums/thread/760186) |

No other launcher is installed on this Mac [V, ls], so there is no reference app to clone.

## Likes and dislikes

| App | People like | People dislike | Sources |
| --- | --- | --- | --- |
| Raycast v2 | Free core does a lot and replaces several apps; extension store and developer experience; polished, consistent UI; fast replies from the team | Non-native (WebKit) and slower; 350 MB–1 GB memory; pushes AI, with bring-your-own-key AI now paid; result order shifts and breaks muscle memory; weak file search; sync costs $96/yr | [1](https://joshcollinsworth.com/blog/alfred-raycast) [2](https://talk.macpowerusers.com/t/sindre-sorhus-switched-from-raycast-to-tinycast/46944) [3](https://manual.raycast.com/ai/byoai) [4](https://talk.macpowerusers.com/t/what-makes-raycast-special/29241?page=4) |
| Alfred | Near-instant, "always seems faster"; best file search, with modifiers to change mode; one-time price; native, loyal users | Workflows hard to learn; default look dated; clipboard and snippets need the Powerpack; no window management built in | [1](https://joshcollinsworth.com/blog/alfred-raycast) [2](https://talk.macpowerusers.com/t/alfred-vs-raycast/44100) [3](https://www.g2.com/products/alfred/reviews) |
| Spotlight (26/27) | Built in and free; clipboard history; actions with inline parameters; quick keys | Slower from 26.3 to 26.5; ranking doesn't learn ("home" gives HomeBot); index misses files and shows web results instead; quick keys only work on actions; no fallback searches; "clunky" | [1](https://sixcolors.com/post/2026/04/im-switching-back-from-spotlight-at-least-for-now/) [2](https://discussions.apple.com/thread/256149405) [3](https://talk.macpowerusers.com/t/so-spotlight-in-macos-tahoe-is-almost-raycast-alfred/40947) |
| LaunchBar | Instant Send ("absolutely crucial"); adaptive abbreviations; does everything without plugins; decades of loyalty; small download (24 MB) | Steep learning curve; ranking feels like "chaos"; drops keys when you type fast; no community or store; looks dated [U] | [1](https://talk.macpowerusers.com/t/launchbar-vs-alfred-2025/40740) [2](https://news.yahoo.com/launchbar-mac-review-003409258.html) |
| Quicksilver | Lightweight; free and open source; object-then-action grammar [K] | Seen as dead; indexing slowed older Macs; recent releases are crash and hang fixes; rivals now do everything it does | [1](https://talk.macpowerusers.com/t/anyone-still-using-quicksilver/10199) [2](https://github.com/quicksilver/Quicksilver/releases) |
| Sol | Fast, light, open source; clipboard, window management and calendar built in; installs with Homebrew | React Native, not pure native; no plugins; needs macOS 14+; little community | [1](https://github.com/ospfranco/sol) [2](https://alternativeto.net/software/sol/about) |
| Tinycast | Fully native; no account; no telemetry | Few features; no sync; users doubt it will stay lean | [1](https://talk.macpowerusers.com/t/sindre-sorhus-switched-from-raycast-to-tinycast/46944) |

**Patterns.** People like these across apps, so version one must have them: speed, ranking that learns from what you pick, native and light, acting on a result without leaving the keyboard, and a fair or one-time price.
People dislike these across apps, so they are where we can do better: lag, result order that shifts, file search tied to a broken Spotlight index, AI and subscription pressure, and steep learning curves.

## Feature matrix

| Feature | Spotlight | Raycast | Alfred | LaunchBar | Version one? |
| --- | --- | --- | --- | --- | --- |
| App launch | Yes | Yes | Yes | Yes | **Yes** |
| Fuzzy and initials matching | Partly | Yes | Yes | Abbreviations | **Yes** |
| Ranking learns from choices | No | Frecency | Per-query | Adaptive | **Yes** (per query, stable) |
| File search | Yes (unreliable) | Weak | Best | Yes + browse | **Yes** (Spotlight index + recent files) |
| Action panel on results (⌘K) | Partly | Yes | → / ⌘/ | Yes | **Yes** |
| Instant Send / act on selection | No | No | Universal Actions | Yes | **Yes** (core actions) |
| Aliases and quick keys on any item | Actions only | Yes | Workflows | Yes | **Yes** |
| Per-item global hotkey | No | Yes | Workflows | Yes | **Yes** |
| Calculator and units | Yes | Yes | Yes | Yes | **Yes** |
| Web search fallback and quicklinks | Web results | Quicklinks | Custom searches | Yes | **Yes** |
| System commands (sleep, lock, empty Trash) | Some | Yes | Yes | Yes | **Yes** |
| Run user scripts and Shortcuts with an argument | Shortcuts | Script commands | Workflows | Script actions | **Yes** (simple) |
| Clipboard history | Yes | Free 3 months | Powerpack | Yes | Later (Spotlight has it free) |
| Snippets and text expansion | No | Yes | Powerpack | Yes | Later |
| Window management | No | Basic | Workflows | No | Later (needs Accessibility) |
| Extension store / plugin API | No | Yes | Workflows | Scripts | No (accepted gap) |
| AI | Apple Intelligence | Pro | Workflows | No | No (deliberate) |
| Cloud sync | iCloud | Pro | Folder | [U] | No (export file instead) |
| Themes | No | Pro | Powerpack | Yes | Later (accent color only) |

## Decisions

1. **Position the app as native, light, private and fast.** It uses SwiftUI/AppKit only, with no account, no telemetry and no AI. Because: the Raycast v2 backlash over WebKit, memory and AI pricing [V](https://talk.macpowerusers.com/t/sindre-sorhus-switched-from-raycast-to-tinycast/46944), and Tinycast's pitch showing the demand. Planned test: memory under 80 MB idle, measured with `footprint` [U].
2. **Ranking learns per query and stays stable.** The order is exact alias, then alias prefix, then initials and fuzzy score, then a boost for what you picked for this query, as in Raycast and Alfred. Every item gets "Reset Ranking". Because: shifting order and poor ranking are top complaints about Raycast, LaunchBar and Spotlight [V](https://sixcolors.com/post/2026/04/im-switching-back-from-spotlight-at-least-for-now/). Planned test: a unit-test table of query to expected first result.
3. **Never drop keys, and target under 50 ms per keystroke.** Queue input until results are ready. Because: LaunchBar dropping keys is a top complaint, and Alfred "waits for my slow input" [V](https://talk.macpowerusers.com/t/launchbar-vs-alfred-2025/40740). Planned test: a self-test that types 20 characters in 200 ms and checks the query [U].
4. **A ⌘K action panel on every result, plus act-on-selection.** Actions include Reveal in Finder, Copy Path, Open With, Quick Look, Show Info and Move to Trash. Because: Raycast and Alfred both build on this pattern [V](https://manual.raycast.com/action-panel), and Instant Send is why LaunchBar users stay [V](https://talk.macpowerusers.com/t/launchbar-vs-alfred-2025/40740). How act-on-selection gets the selection (Finder via Apple Events, text via Accessibility) is [U] and must be tested.
5. **Aliases (quick keys) and an optional global hotkey on any item.** Because: Spotlight's quick keys only work on actions [V](https://sixcolors.com/post/2026/04/im-switching-back-from-spotlight-at-least-for-now/), which is a clear way to beat it.
6. **Ship outside the Mac App Store, notarized with Developer ID.** Because: window management, auto-paste, scripts and full file search all fail or degrade in the sandbox [V](https://developer.apple.com/forums/thread/810677), and Raycast and Alfred ship outside the store [K]. Accessibility is requested only when a feature that needs it is turned on.
7. **The default hotkey is ⌥⌘Space, and onboarding offers to take over ⌘Space.** The default needs ⌘ or ⌃ because Option-only combos fail [V](https://developer.apple.com/forums/thread/763878?page=2). ⌘Space is taken by Spotlight on this Mac [V, PlistBuddy], so onboarding offers a step that opens Keyboard Shortcuts settings. Use the KeyboardShortcuts library [V](https://swiftpackageregistry.com/sindresorhus/KeyboardShortcuts).
8. **Find apps with `NSMetadataQuery`, with a folder-scan fallback.** Because: `/Applications` alone holds 26 of 352 apps here [V, mdfind]. Planned test: a self-test that the app count is at least the `mdfind` count.
9. **The panel is an `NSPanel`** (non-activating, floating, joins all Spaces), centred in the upper third, standard and compact sizes. Planned test: snapshot it over a full-screen app and with Stage Manager on [U].
10. **Leave out of version one:** clipboard history (Spotlight has it free), extensions, AI and sync. These are accepted gaps for the brief.
11. **Pricing: free core with a one-time Pro, or one-time paid, decided in the brief.** Because: every competitor gives the core away [V](https://www.raycast.com/pricing), and subscriptions draw complaints [V](https://simplyproductive.substack.com/p/why-im-switching-from-alfred-to-raycast). Whether people will pay is [U].
12. **Expose the app's actions to Spotlight and Shortcuts through App Intents.** It works with the platform rather than against it [K]. Low priority.

## Open questions
- [U] Is pasteboard privacy enforced on macOS 27? Test with a `changeCount` probe before the clipboard story.
- [U] Can the panel show over full-screen apps and Stage Manager? Snapshot test.
- [U] Is Spotlight's index on macOS 27 good enough for file search, or do we need our own index of recent and favorite folders? Compare `mdfind` against `find` on ~/Documents.
- [U] Best way to get the selection for act-on-selection: the Finder selection over Apple Events, and text via Accessibility or a synthetic ⌘C.
- [U] LaunchBar's price, and the Alfred 6 release date.
- [U] Memory and keystroke-latency targets (80 MB, 50 ms) must be measured against Alfred and Raycast.
