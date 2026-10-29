# Engine spike: crisp_notation 0.13.0

Date: 2026-10-29
Branch: `spike/engine` (throwaway; not merged)
Inputs: the private sample (`07 Collateral Damage.xml`, MusicXML 2.0 from Guitar Pro 8.1.5) and the alphaTab test corpus (`test-data/` of github.com/CoderLine/alphaTab, MPL-2.0, kept in `test_assets_private/`, never committed): 18 GP3, 23 GP4, 49 GP5, 35 GPX, 53 GP7, 60 GP8 and 27 MusicXML files.

## Results per check

| # | Check | Result |
|---|---|---|
| 1 | Real files render as notation over tab with techniques | **Partial** |
| 2 | Code-built 7- and 8-string song, mixed meters, tempo change, four voices renders | **Pass** (widget test) |
| 3 | Code-built song saved as `.gp` survives | **Partial**; owner check in Guitar Pro 8 pending |
| 4 | MIDI from `playbackTimeline` plays in time through `AVAudioSequencer` | **Not run** |
| 5 | Calls for track name, tuning, string count, program, percussion, string pins | **Gaps** |

### 1. Parsing and layout

- **Parsing**: 236 of 248 files parse. The failures are 6 files with a 20/32 time signature (`FormatException: invalid GP time signature 20/32`), 5 `score-timewise` MusicXML files (only `score-partwise` is read), `serenade.gp5` (truncated-record error) and `orphan-tempo-automation.gp` (`RangeError`).
- **Speed**: the private sample (1.9 MB, 7 parts, 153 bars) parses in 58 ms on the Mac. Its parts lay out in 2–59 ms each.
- **Layout without a screen** (`layoutNotationTab` over every part of every parsed file): 551 of 552 parts lay out. The one failure is `buzzroll.xml` (`strokes must be 1..5: 0`).
- **Widget rendering** (`NotationTabView` in `flutter test`): all 7 parts of the private sample, `bends-advanced.gp`, `effects.gp`, and the 7- and 8-string songs render without exceptions.
- **On the iPhone Duo simulator**: one `NotationTabView` throws `ArgumentError: annotation/chord symbol references an unknown element id: e92` from `layout_annotations.dart:536`. It does not reproduce in `flutter test`, which suggests it depends on real font metrics. Simulator screenshots came back black on every display tried, so which sample throws, and what the rest look like on the device, is still unconfirmed.
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

**Owner check pending**: open `roundtrip.gp` in Guitar Pro 8 and report what you see.

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

1. **MusicXML guitar import**: tunings from `<staff-tuning>`, string pins from `<string>`/`<fret>`, and bends, hammer-ons/pull-offs, slides, vibrato, palm mute, let ring, harmonics and dead notes. Without this, your sample shows no techniques and wrong fingering.
2. **Guitar Pro track headers**: expose tuning, name, MIDI program and percussion from the GP3–GP5 and GPIF readers.
3. **Voices 3–4 and tempo changes** in Guitar Pro read and write.
4. **Line wrapping** for notation over tab, with the id filtering described above.
5. **The device-only annotation layout error.**
6. **Smaller parser fixes**: the 20/32 meter, timewise MusicXML, the two crashing files.
7. **A decision on unplayable notes**, which save as rests.

All of these sit inside one pure-Dart codebase with tests and fuzzing. Items 1, 3 and 4 are each several days of careful work; the rest are small.

## The alternative: alphaTab in a web view

The spec's last-resort fallback. alphaTab reads GP3–GP8 and MusicXML (guitar techniques included), wraps lines, follows playback with a cursor, and plays through its built-in SoundFont synth with mute/solo, speed and loops. It also writes `.gp`. The cost is architectural: the score and its model live in JavaScript inside a `WKWebView`, so the editor's commands run in JavaScript behind a bridge, and DuoTab becomes a Dart + TypeScript codebase. Native playback through `AVAudioSequencer` would no longer be needed.

## Decision

**Not taken here: it goes to the owner.** Both paths are viable. The choice decides the language of the editor and the size of Plans 2–4, so Tasks 8 and 11 wait for it.
