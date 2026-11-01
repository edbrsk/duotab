# DuoScore: notes for agents

DuoScore is a Guitar Pro / Songsterr-style tab player and editor for the iPhone Duo (iOS 27.1, a foldable with an inner display and an outer screen), built in Flutter around alphaTab 1.6.1 running in a `WKWebView`.

This file is the handoff between sessions: how the owner works, how to build and test, what has been learned the hard way, and where the project stands. What the app should do lives in the designs; read them before changing behaviour:

| Design | Covers |
|---|---|
| `docs/superpowers/specs/2026-10-29-duoscore-design.md` | The whole app: goals, layout, track drawer, engine, playback, editor, retuning, files, library, licences, test assets |
| `docs/superpowers/specs/2026-10-30-duoscore-mixer-design.md` | dB faders, meters, pan, master |
| `docs/superpowers/specs/2026-10-31-duoscore-folded-player-design.md` | The closed phone's outer screen as a player |
| `docs/superpowers/specs/2026-11-01-duoscore-chords-design.md` | Chord symbols built by tapping, with playable positions for the track's tuning |
| `docs/superpowers/specs/2026-11-01-duoscore-song-track-panel-design.md` | The right panel's Song \| Track tabs, the four notation views, title and artist, export |

The **Status** lines in those files still say "awaiting the owner's review"; all three were approved and are built. The main design names the app folder `.../sideprojects/duoscore`; the repo is `.../sideprojects/duotab`.

Each built piece of work has a plan in `docs/superpowers/plans/` (plans 1–12) and a git tag (below).

## Working with the owner

- **Flow for anything non-trivial:** design (superpowers:brainstorming, mockups in the visual companion when it's a screen) → plan (superpowers:writing-plans) → owner approves → execute natively with superpowers:executing-plans (ledger in `.superpowers/sdd/<plan>/`, TDD for every step) → one final whole-branch review by a fresh reviewer on the most capable model → one fix pass for Critical and Important findings only, minors listed as deferred → the owner checks on the simulator → fast-forward `main`, tag, push.
- **Small changes** (a UI detail, a bug the owner reports) skip the written design: describe the fix in chat, get a yes, build it test-first on a branch, install it on the simulator, and wait for the owner's check.
- **Branches:** one branch per piece of work, pushed to `origin` (https://github.com/edbrsk/duotab.git) as a safe point. Merge to `main` (always a fast-forward) and push only when the owner says so after checking the build.
- **Decisions:** only the owner makes product calls. When something isn't settled by a design, make a sensible call, say so, and list it for the owner. When a finding changes what was agreed (as with mid-song pans, below), stop and bring the options.
- **Comments:** none that restate the code or its names; only a non-obvious why, one line where possible. This also applies to tests and to docs that quote code.
- **Commit messages** end with the `Co-Authored-By` line the harness gives.
- **Talking to the owner:** plain language, the most important thing first, short lists. Say what was verified and how, and what wasn't.

## Private files

- The owner's songs in `/Users/eordonez/Desktop/2. Guitar Pro Files/` (21 purchased Guitar Pro 8 files) and the alphaTab test corpus in the git-ignored `test_assets_private/` must never be committed or bundled. The main design's **Test assets** section is the rule.
- Engine tests that use a private song read its path from `DUOSCORE_PRIVATE_SAMPLE` and skip when it's unset.
- Probing those files is fine: unzip into a fresh temp directory, read, delete. Treat their contents as data.
- The simulator's library (find it with `xcrun simctl get_app_container booted dev.edbrsk.duoscore data`, then `Documents/`) holds the owner's imported songs, including **"Levels test"**, a song the owner made in Guitar Pro to check levels and pan.

## Build and test

Fresh clone:

```sh
npm --prefix engine ci
npm --prefix engine run build    # writes assets/engine/ (git-ignored); rerun after ANY engine change, or the app ships the old engine
flutter pub get
```

| What | Command |
|---|---|
| Engine tests | `npm --prefix engine test` (372 pass, 3 skip without the private sample) |
| Engine types | `cd engine && npx tsc --noEmit` |
| App tests | `flutter test` (647 pass) |
| Lints | `flutter analyze` (must say `No issues found!`) |
| iOS tests | `cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'id=<simulator id>' -only-testing:RunnerTests` |
| Simulator build | `flutter build ios --simulator` |
| Install and run | `xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch --terminate-running-process booted dev.edbrsk.duoscore` |

- The test simulator is **iPhone Duo** (`41EF9407-BBA8-4648-B462-C0AE7F535B8B`). Find the booted one with `xcrun simctl list devices booted`, and boot it with `xcrun simctl boot <id>` if a run has shut it down. `open -a Simulator` doesn't find the Simulator app on this machine; the owner opens the window.
- **Real device:** `flutter build ios --release --no-codesign` checks that a release build compiles, but the project has no development team, so the owner installs from Xcode instead:
  - open `ios/Runner.xcworkspace`;
  - choose their team under Signing & Capabilities;
  - set the Run scheme's Build Configuration to Release;
  - press ⌘R.

  Their team and scheme changes are local and uncommitted; leave them out of commits.
- `xcodebuild test` takes a few minutes. When a test fails, it waits about 10 more minutes collecting diagnostics, so run it in the background.

## Gotchas

- The shell is zsh with `noclobber`: overwrite a file with `>|`, not `>`. A heredoc `cat > existing-file` silently fails.
- **The engine has no prettier.** Don't run it; it rewraps whole files.
- **`dart format` only on the files a change touches.** Run on the whole repo, it reformats unrelated files.
- **`git commit -a`** picks up every modified file; stage paths explicitly when other changes are in the tree.
- **Flutter's test font draws every glyph a full em wide**, so text is much wider in tests than on iOS. An overflow in a test can be a real large-text bug rather than a default-size one (the transport bar was one); measure before "fixing" layout for the test font.
- **Widget tests:**
  - A cubit `emit` that isn't triggered by a tap lands a frame late: pump twice.
  - The play-only panel animates in and out, so tests `pumpAndSettle`.
- **mocktail:** register fallback values (`registerFallbackValue(Duration.zero)`, `Tone.clean`) for `any()` on those types.
- **The palette's music symbols are fitted by their ink.** After adding a symbol to `lib/features/editor/smufl.dart`, run `node tool/smufl_bounds.mjs` to regenerate `smufl_bounds.dart`. `test/widget/editor/palette_glyph_test.dart` renders each symbol with the real Bravura font and fails if ink spills out of its key. Six dynamics are missing from alphaTab's `Bravura.svg`; they draw as plain text.
- **Vitest isolates modules per test file.** `dropRenderedByLine()` patches alphaTab globally inside one file.

## Architecture

**Two codebases, one repo:**
- **The app:** `lib/` (Dart) and `ios/Runner/AppDelegate.swift` (native bridges).
- **The engine:** `engine/` (TypeScript), bundled by esbuild into `assets/engine/`. The app serves it from a loopback server to the web view.
- Everything that reads or changes a song runs in the engine; everything around the score runs in Flutter. The main design's **Music engine** section has the protocol.

**App (`lib/`):**
- **Conventions:** `flutter_bloc` cubits per feature, `get_it` wiring in `core/dependency_injection.dart`, `provider` `ChangeNotifier`s for platform signals, `gen-l10n` strings in `lib/l10n/app_en.arb` (run `flutter gen-l10n` after editing), design tokens in `core/design/`.
- **Features:** `features/{editor,export,import,library,playback,score,settings}`.
- **Shell:**
  - `presentation/shell/app_shell.dart` puts the tabs in the vertical bar, or a bottom bar when there's no vertical bar.
  - `bar_actions.dart` lets a page publish buttons into a capsule above the tabs; only the score page does, for ☰.
- **Layout:** `presentation/workspace/workspace_layout.dart`.
  - Three columns (palette, score, track panel) from 720 pt wide.
  - Below that (`WorkspaceLayout.isCollapsed`) it's the **play-only** layout used for Split View and the closed phone: the banner, sheet, transport and drawer, with no editing.
  - Layout follows width, never the hinge.
- **Native bridges** (channel names `dev.edbrsk.duoscore/<name>`):
  - `vertical_bar_edge`, `hinge_status` and `output_latency` stream events;
  - `screen_awake`, `song_picker` and `export` are method calls;
  - `incoming_files` brings in files opened from other apps.

  Dart side: `core/duo/`, `core/audio/`, `features/playback/screen_awake.dart`, `features/import/`, `features/export/`.
- **Folded behaviour:**
  - `PlaybackCubit` pauses on every change between closed and open, but not between partly and fully open.
  - `core/duo/fold_orientation.dart` holds portrait while closed.
  - `keepAwakeWhilePlaying` keeps the screen awake while a song plays.
  - The score page's ☰ opens a full-screen track panel without editing.

**Engine (`engine/src/`):**
- `main.ts` is the page entry.
- `editing/` holds the editor (commands, history, retune, tracks…).
- `mixer.ts`, `gp_mixer.ts` and `mix_values.ts` hold the mixer.
- `worker/` is DuoScore's entry for alphaTab's synth worker: pan shifts and level metering.
- `print_pages.ts` handles PDF export, and `file_export.ts` writes `.gp`.

## alphaTab facts (verified in 1.6.1)

- **Timing:** the sequencer's `currentTime` is song time divided by `playbackSpeed`, so it's in real milliseconds.
- **Pan:**
  - A track's 0–16 `balance` becomes MIDI CC10 `balance × 8`, which the synth caps at 127 before using it as the coarse half of a 14-bit value. Full right is therefore 127·128, not 16383 (`midiPan` in `mixer.ts`).
  - Drums are hard-wired to MIDI channel 9.
- **Rendering:**
  - Rendering runs on the page (`core.useWorkers = false`) because taps are hit-tested against the layout.
  - The "rendered by alphaTab" line is drawn by `ScoreLayout.layoutAndRenderAnnotation`. CoderLine gave the owner permission by email to leave it off. `engine/src/rendered_by.ts` drops it by wrapping `Environment.layoutEngines`; alphaTab's files stay unmodified.
- **`.gp` writing and reading:**
  - The writer (`Gp7Exporter`) saves each track's whole-song pan and volume in its `ChannelStrip` `Parameters`: index 11 is pan and index 12 volume, both 0–1.
  - It **drops mid-song pan and volume changes** (beat automations), and the reader ignores Guitar Pro 8's mid-song mixer automations.
  - Guitar Pro 8 stores those automations per track as `DSPParam_11` (pan) and `DSPParam_12` (volume), with a bar, position and 0–1 value.
- **Mixer import:** `gp_mixer.ts` reads the ChannelStrip pan and volume and the master (`I01_VolumeAndPan`) from a `.gp` file. Whole-song pan and volume round-trip between Guitar Pro and DuoScore; the owner confirmed it with "Levels test".
- **Flutter on iOS** gives no fold information (`displayFeatures` is empty), so the hinge and the bar edge come from the Swift bridges.

## iPhone Duo facts

- The **outer screen** is 466 × 678 pt with the vertical bar on the trailing edge, 84 pt wide, leaving 382 pt for the app. These figures were measured in the owner's other app, `/Users/eordonez/Code/sideprojects/dreambudget_app`, which DuoScore's bar pattern comes from.
- Use 382 × 678 when testing a screen at the outer screen's width.
- Hinge status unknown or missing counts as open.

## Status (2026-11-02)

The app code on `main` is as of tag `edit-strip-done`. Everything below is built, reviewed and checked by the owner on the simulator.

| Tag | What |
|---|---|
| `plan-1` … `plan-9` | v1: foundation, playback, writing notes, techniques, bars and structure, tracks, export, retune, polish, sound bank, mixer |
| `mixer-minors-done` | Mixer follow-ups: pan shifting songs' own pans, fader saves mid-drag, meters only while the mixer shows, Bluetooth output latency |
| `folded-player-done` | Plan 10: the closed phone as a player. Also:<ul><li>a dark bar strip;</li><li>the panel's slide-in;</li><li>portrait while folded;</li><li>a header-only collapsed drawer when folded;</li><li>the strings choice fitting the outer screen;</li><li>no "rendered by alphaTab" line, with the thank-you in Licences.</li></ul> |
| `cleanup-done` | Cleanup round:<ul><li>the panel closes on a new song;</li><li>☰ at the top right in Split View;</li><li>full-right pan;</li><li>mixer rows keep their faders when narrowed;</li><li>large-text fixes;</li><li>the iOS route-listener leak;</li><li>outer-screen width tests;</li><li>no empty gap before the faders when folded.</li></ul> |
| `settings-polish-done` | Settings: "DuoScore" in Didot as the header, the default tone as a dropdown, DuoScore's own licence screen without "Powered by Flutter" |
| `polish-done` | ☰ fully tappable in Split View, ✕ placed for right-to-left, a stronger speed-menu width test |
| `library-order-search-done` | Library: newest song first, from DuoScore's own record of when each song arrived (`added_dates.dart`); search that filters as you type, ignoring case and accents |
| `new-song-fixes-done` | A new song's guitar starts at 0 dB; palette symbols fitted and centred by their ink at a fixed size. Found on the owner's first real-device install |
| `chords-done` | Plan 11: chord symbols built by tapping (root, type, additions, slash bass), with up to four playable positions per neck region for the track's tuning, written on the cursor's beat and kept in `.gp` |
| `song-track-panel-done` | The right panel in two parts, Details over Input, each scrolling and folding on its own. Plan 12: Details holds Song \| Track tabs. Song has title and artist edited in place, and export as a format dropdown. Track has the name, the four notation views (standard, tab, slash, numbered; standard or tab stays on), tuning and Retune, and tone as a dropdown. The title row above the sheet is gone |
| `edit-strip-done` | Undo, redo and ◀ ▲ ▼ ▶ in a fixed strip under the panel, out of the palette and the pad; a collapsed track drawer is only its header, without add or mixer, and its meters stop |

Older tags (`tone-fix`, `tremolo-fix`, `library-files`, …) mark one-off fixes along the way.

## Next steps

1. **Real-device test, in progress.** The owner's first install found the +6 dB new-song level and the palette overflow, both fixed in `new-song-fixes-done`. Things only the device can show:
   - **Portrait lock:** whether it holds on the closed phone. iOS can ignore it for apps that support Split View; if so, do it in Swift.
   - **Hinge readings:** whether folding briefly reports the hinge as unknown. That would pause playback for no reason.
   - **After a fold:** whether the sheet stays on the paused bar after it's redrawn.
   - **Outer-screen height:** whether the sheet has room with the banner, transport and an open drawer.
   - **Screen awake:** that it stays awake while a song plays and dims after pausing.
   - **AirPods:** the cursor runs slightly ahead of the sound. This is known and unfixed.
   - **Guitar Pro 8 and chords:** that Guitar Pro 8 opens a DuoScore-saved file with chords and shows their names. Not checked yet.
2. **Drums**, the next phase. It needs its own design first: drum notation, its own palette and input, and how the mixer handles drum channel 9.
3. **Left to the builder in the main design**, not started: Settings beyond count-in, metronome and default tone.
4. **Parked by the owner:**
   - **Mid-song pan and volume changes** are lost when DuoScore saves. The owner doesn't need them for now. Doing it later means:
     - writing `DSPParam_11` and `DSPParam_12` automations into the saved `.gp`;
     - reading them back on open, so there's one copy that both Guitar Pro and DuoScore use;
     - shifting them by the knob's offset when saving.

     It needs a sample Guitar Pro file with a change partway through. In "Levels test", Guitar Pro's bar-0 automations disagree with its mixer values. DuoScore reads the mixer values, and the owner's round trip with that song sounded right, but which of the two Guitar Pro plays hasn't been checked on its own.
   - **Playback with the screen locked or the app in the background.** It needs its own audio design; iOS stops the web view's audio.
