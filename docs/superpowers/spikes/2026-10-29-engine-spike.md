# Engine spike: crisp_notation 0.13.0

Date: 2026-10-29
Branch: `spike/engine` (throwaway; not merged)
Inputs: the private sample (`07 Collateral Damage.xml`, MusicXML 2.0 from Guitar Pro 8.1.5) and the alphaTab test corpus (`test-data/` of github.com/CoderLine/alphaTab, MPL-2.0, kept in `test_assets_private/`, never committed): 18 GP3, 23 GP4, 49 GP5, 35 GPX, 53 GP7, 60 GP8 and 27 MusicXML files.

## Results per check

| # | Check | Result |
|---|---|---|
| 1 | Real files render as notation over tab with techniques | **Partial** |
| 2 | Code-built 7- and 8-string song, mixed meters, tempo change, four voices renders | **Pass** (widget test) |
| 3 | Code-built song saved as `.gp` survives | **Fail**: Guitar Pro 8 cannot open the file (owner check) |
| 4 | MIDI from `playbackTimeline` plays in time through `AVAudioSequencer` | **Not run** |
| 5 | Calls for track name, tuning, string count, program, percussion, string pins | **Gaps** |

The owner's own songs (`/Users/eordonez/Desktop/2. Guitar Pro Files/`, 21 Guitar Pro 8 files, licensed, never committed) were added after the first pass. The MusicXML export of Collateral Damage is no longer on the Desktop; its `.gp` original is in that folder.

### 1. Parsing and layout

- **Parsing**: 236 of 248 files parse. The failures are 6 files with a 20/32 time signature (`FormatException: invalid GP time signature 20/32`), 5 `score-timewise` MusicXML files (only `score-partwise` is read), `serenade.gp5` (truncated-record error) and `orphan-tempo-automation.gp` (`RangeError`).
- **Speed**: the private sample (1.9 MB, 7 parts, 153 bars) parses in 58 ms on the Mac. Its parts lay out in 2–59 ms each.
- **Layout without a screen** (`layoutNotationTab` over every part of every parsed file): 551 of 552 parts lay out. The one failure is `buzzroll.xml` (`strokes must be 1..5: 0`).
- **Widget rendering** (`NotationTabView` in `flutter test`): all 7 parts of the private sample, `bends-advanced.gp`, `effects.gp`, and the 7- and 8-string songs render without exceptions.
- **On the iPhone Duo simulator** (owner's screenshot): the private sample's first guitar part throws `ArgumentError: annotation/chord symbol references an unknown element id: e92` from `layout_annotations.dart:536`, and the whole view becomes an error box. The other four samples render. It does not reproduce in `flutter test`, which suggests it depends on real font metrics.
- **No line wrapping**: `NotationTabView` draws the whole part as one horizontal system (`layout.width × staffSpace`). Nothing in either package wraps notation-over-tab into lines. Wrapping has to be built by cutting the `Score` into per-line `Score`s. That cut has to drop every id-referencing list entry (annotations, slurs, bends, voicings, and so on) whose ids fall outside the line: cutting `measures` alone throws the error above.

**Guitar Pro import keeps techniques.** Counts read back from the technique test files:

| File group | What came back |
|---|---|
| `bends.*` (GP3–GP7) | 3 bends |
| `hammer.*` | 6 hammer-on/pull-off slurs |
| `slides.*` | 3–5 slides |
| `vibrato.*` | 2–4 vibratos |
| `dead.*` | 4 dead-note marks |
| `harmonics.*` | 5 harmonic marks (0 from `.gpx`) |
| all | string pins (`tabVoicings`) for every note |

Voice 2 is read; no Guitar Pro file produced voice 3 or 4.

**The owner's 21 Guitar Pro 8 files** all parse (3–156 ms each), with bends, slides, hammer-ons and string pins. **Palm mute, vibrato and let ring are dropped from every one.** Collateral Damage `.gp`, all 7 tracks:

| | crisp reads | in the file's GPIF |
|---|---|---|
| vibratos | 0 | 242 mentions |
| palm mutes | 0 | 62 mentions |
| let rings | 0 | 46 mentions |

**MusicXML import drops guitar tab data.** For the private sample, `multiPartScoreFromMusicXml` returns 7 parts, 153 bars, 7 time signatures and 109 slurs, with the MIDI program on each part. It returns **0** string pins, **0** bends, **0** vibratos, **0** palm mutes and **0** slides, against the file's 4,030 frets, 321 bends, 266 vibratos, 699 palm mutes and 84 slides. The reader handles `<technical>` only for up-bow, down-bow and fingering, and never reads `<staff-details>`/`<staff-tuning>`.

### 3. Saving `.gp` (`multiPartToGpif` + `writeGpFromGpif`)

Written to `test_assets_private/spike/roundtrip.gp` and read back with crisp:

| Survives | Lost |
|---|---|
| both tracks and their names | voices 3 and 4 |
| 7- and 8-string tunings (the file is written with them) | the tempo change in bar 2 |
| the 7/8 → 4/4 time-signature changes | |
| voice 2 | |

A note no string can reach is written as a **rest** (B1 on a 6-string standard tuning came back as a whole rest).

**Guitar Pro 8 fails to open `roundtrip.gp`** (owner check), so crisp's `.gp` writer does not produce files Guitar Pro accepts, at least for this song.

### 4. Playback

Not run in this spike. The spike's time went on the gaps above, and the decision below does not depend on it. Known from the API: `scoreToMidi` is format 0 with one tempo and velocity 80, so DuoTab writes its own file in either option (spec, Playback).

### 5. Track information on import

| Information | MusicXML | Guitar Pro (`.gp`, `.gpx`, GP3–GP5) |
|---|---|---|
| Song title | `parts[i].metadata.title` | not set |
| Track name | `metadata.instrument` (part name) | not set; `gpifTrackNames(gpif)` for `.gp`/`.gpx` only |
| MIDI program (0-based) | `metadata.midiProgram` | not set |
| Percussion | `metadata.isPercussion` | not set (`drum-tabs.gp` reports `false`) |
| Tuning, string count | not read | read internally to turn frets into pitches, not exposed |
| String per note | not read | `Score.tabVoicings` |

`Tuning` is not stored on a `Score`; layout takes it as an argument (`NotationTabView(score:, tuning:)`), so DuoTab's `SongTrack.tuning` is the right home for it in any case.

`NotationTabView({required Score score, required Tuning tuning, double staffSpace = 12, double staffGap = 5, CrispNotationTheme theme, Set<String> highlightedIds, int capo = 0, bool showTuning = false})`

## What keeping crisp_notation costs

Work DuoTab would add to a fork, or around it:

1. **MusicXML guitar import**: tunings from `<staff-tuning>`, string pins from `<string>`/`<fret>`, and bends, hammer-ons/pull-offs, slides, vibrato, palm mute, let ring, harmonics and dead notes. Without this, a MusicXML file shows no techniques and wrong fingering.
2. **Guitar Pro track headers and techniques**: expose tuning, name, MIDI program and percussion from the GP3–GP5 and GPIF readers, and read palm mute, vibrato and let ring from Guitar Pro 8 files.
2a. **A `.gp` writer Guitar Pro 8 accepts.**
3. **Voices 3–4 and tempo changes** in Guitar Pro read and write.
4. **Line wrapping** for notation over tab, with the id filtering described above.
5. **The device-only annotation layout error.**
6. **Smaller parser fixes**: the 20/32 meter, timewise MusicXML, the two crashing files.
7. **A decision on unplayable notes**, which save as rests.

All of these sit inside one pure-Dart codebase with tests and fuzzing. Items 1, 3 and 4 are each several days of careful work; the rest are small.

## The alternative: alphaTab in a web view

The spec's last-resort fallback, measured with `@coderline/alphatab` 1.6.1 in Node (import and `.gp` export only; rendering and playback not tried). Scripts: `spike/alphatab_probe/` on the spike branch.

- **Reading**: 266 of 268 files, all 21 of the owner's included, in 3–156 ms. It reports track names, MIDI programs, tunings (7-string tracks found, 10 percussion tracks flagged), voices 2–3, tempo automations and time-signature changes. The two failures are `chord-name-overflow.gp5` (out of memory) and `orphan-tempo-automation.gp` (a `TypeError`, possibly in the probe's own counting).
- **Collateral Damage `.gp`**, all 7 tracks: 4,030 notes, 290 bends, 266 vibratos, 697 palm mutes, 399 let rings, 81 slides, 213 hammer-ons/pull-offs, 14 dead notes, 17 harmonics. The tuning (E♭ standard) and the instrument (program 29, 0-based = Overdriven Guitar) come back on every track.
- **Saving `.gp`** (`Gp7Exporter`): exporting that song and reading it back gives identical counts. Whether Guitar Pro 8 opens the exported file is pending (`test_assets_private/spike/alphatab-07 Collateral Damage.gp`).

On top of that, alphaTab wraps lines, follows playback with a cursor, and plays through its built-in SoundFont synth with mute/solo, speed and loops. The cost is architectural: the score and its model live in JavaScript inside a `WKWebView`, so the editor's commands run in JavaScript behind a bridge, and DuoTab becomes a Dart + TypeScript codebase. Native playback through `AVAudioSequencer` would no longer be needed.

## Decision

**Not taken here: it goes to the owner.** The choice decides the language of the editor and the size of Plans 2–4, so Tasks 8 and 11 wait for it.

Recommendation: **alphaTab**. On the owner's own songs it reads everything crisp drops, and its `.gp` export survives a round trip; crisp's `.gp` files do not open in Guitar Pro 8. Keeping crisp means rebuilding import, export and line wrapping before any app feature works.

## Step 0b: alphaTab in a web view on the iPhone Duo simulator

Probe: `spike/webview_probe/` on the spike branch. `webview_flutter` `WebViewWidget`, alphaTab 1.6.1's `dist/` served by a `dart:io` `HttpServer` on `127.0.0.1:0`, Collateral Damage `.gp`, one track rendered with `StaveProfile.ScoreTab`, `PlayerMode.EnabledSynthesizer` with `sonivox.sf2`.

| # | Check | Result |
|---|---|---|
| 1 | Notation over tab, wrapped into lines | rendered without errors; visual check by the owner pending |
| 2 | Plays in time, cursor follows | player ready; listening check by the owner pending |
| 3 | `file://` or loopback server | **loopback server needed**: from `loadFlutterAsset`, the module import fails with `TypeError: Cross-origin script load denied by Cross-Origin Resource Sharing policy.` |
| 4 | Load and render time | page boot 197 ms; song loaded (7 tracks) 346 ms; SoundFont 534 ms; player ready 538 ms; first render 578 ms |
| 5 | Bridge round trip (Dart `runJavaScript` → page → `JavaScriptChannel`) | median 0.64 ms, max 116 ms over 20 pings |

Settings that worked, relative to the page URL: `import('./alphatab/alphaTab.mjs')`; `core.fontDirectory = <page>/alphatab/font/`; `player.soundFont = <page>/alphatab/soundfont/sonivox.sf2`; `player.enableCursor = true`; `player.scrollElement = document.scrollingElement`; song loaded with `api.load(<page>/song.gp)`. The server must send `text/javascript` for `.mjs`. Worker and worklet were found by alphaTab next to `alphaTab.mjs` without extra settings.
