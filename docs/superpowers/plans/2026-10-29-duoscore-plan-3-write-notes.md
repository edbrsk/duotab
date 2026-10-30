# DuoScore Plan 3: Write Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write and change guitar parts on the iPhone Duo the way Guitar Pro does: create a song, tap a string, type the fret, pick note values, rests, dots and voices from a palette, see bars that are too long or short in red, undo and redo. Songs save automatically, and an opened file is never overwritten.

**Architecture:**
- **Engine.** Every edit is a pure function on alphaTab's `Score` in `engine/src/editing/`, tested headless in Node. The engine applies it to `api.score`, re-checks bar lengths, re-renders, regenerates the MIDI and replies with the new edit state.
- **Taps.** The engine resolves a tap to bar, beat and string from alphaTab's layout. That layout is only on the page when alphaTab renders on the main thread, so the engine stops using a render worker.
- **Dart.** An `EditorCubit` holds the cursor and the palette choices; the fret pad and the palette send commands. A `SongSaver` writes the engine's `.gp` export to Documents, into a `<name> (DuoScore).gp` copy the first time an opened file is edited.

**Tech Stack:** as Plans 1–2. alphaTab 1.6.1 APIs added: `model.Beat`, `model.Note`, `model.Voice`, `model.Bar`, `model.MasterBar`, `Voice.addBeat`/`insertBeat`, `Beat.addNote`/`removeNote`, `Score.finish`, `MasterBar.calculateDuration`, `model.JsonConverter.scoreToJsObject`/`jsObjectToScore`, `exporter.Gp7Exporter`, `importer.AlphaTexImporter`, `rendering.ScoreRenderer` (headless `svg` engine, for tests), `renderer.layout` staff systems and their `TabBarRenderer.getLineY` (internal, pinned by the exact alphaTab version), `boundsLookup.getBeatAtPos`, `api.render`, `settings.core.useWorkers`.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md` (sections Editor, Files, Screen layout, Music engine)

**Branch:** `plan-3-write-notes`, from `main`.

## Roadmap

The editor is split in two so each plan stays reviewable; retune and export move one plan later.

| Plan | Delivers |
|---|---|
| 3 Write notes (this) | standard notation above tab with per-track staff toggles, new song, tap-to-cursor, fret pad, palette (voices, note values, rests, dots) with collapse, bar check, undo/redo, autosave and the "(DuoScore)" copy |
| 4 Notation tools | tuplets, ties, grace notes, accidentals, dynamics, guitar techniques, articulations; bar tools (clef, time signature per bar, key signature, repeats, alternate endings, segno/coda, tempo marking); insert, delete, copy and paste bars; guitar track management in the drawer; tones written into saved songs |
| 5 Retune and export | retuning, automatic fingering, `.gp` and PDF export, share sheet |

## Global Constraints

Plans 1–2's Global Constraints all apply. In addition:

- alphaTab numbers strings from the lowest: string 1 is the lowest-pitched string, and `staff.tuning` lists the top string first. `EditPosition.string` uses alphaTab's numbering.
- Frets run 0–24 (the spec's default highest fret).
- Note values are alphaTab `Duration`s: whole 1, half 2, quarter 4, eighth 8, sixteenth 16, thirty-second 32, sixty-fourth 64; dots 0–2.
- A bar is checked per voice that has notes or rests; a voice whose only beat is `isEmpty` is unused and not checked. The amount off is shown as a fraction of a whole note: `⅛ short`, `3/16 long` (a Unicode vulgar fraction when one exists, otherwise `n/d`), with 3840 ticks per whole note.
- Undo keeps at most 100 steps per open song; opening a song clears it.
- Files: an opened file is never written. The first edit writes `<name> (DuoScore).gp` beside it (through `uniqueDestination`), and every later save writes that copy. A song created in the app saves to `<title>.gp`. The app remembers the files it created or copied in `<Application Support>/owned.json`; only those are ever overwritten.
- Autosave runs 1 s after the last edit.
- Tuning presets for a new song: 6 strings: Standard E, E♭, D, C♯, C, B, Drop D, Drop C♯, Drop C, Drop B; 7 strings: Standard B, A, Drop A; 8 strings: Standard F♯, E, Drop E. A custom tuning picks each string's note.
- Exact copy: `Make DuoScore wider to edit` (existing), `New song`.

## Review Focus

0. **A file that saved a guitar track with notation or tab switched off** must still open with both drawn; only the owner's own toggles hide one. Test: Task 0 `opens every string track with notation and tab`.

1. **Editing an opened file** must never write to it, including when a `<name> (DuoScore).gp` already exists (the copy becomes `<name> (DuoScore) (2).gp`) and when the opened file is itself an earlier copy the app no longer remembers. Tests: Task 8 `the first edit of an opened file writes a copy beside it`, `an existing copy name gets a counter`, `a file the app did not create is never written`.
2. **Moving the cursor past the last beat of the last bar** must append a bar in the time signature in force, and the bar check must cover it. Test: Task 1 `moving right from the last beat appends a bar`.
3. **The engine restarting during editing** must reopen the copy being edited, not the original, and keep the cursor's track. Test: Task 8 `an engine restart reopens the saved copy`.
4. **Fret entry edge cases**: a second digit that would pass 24, a digit after the time window, and ⌫ on a rest. Tests: Task 6 `a second digit past 24 starts a new fret`, `a digit after the window starts a new fret`; Task 1 `deleting the only note leaves a rest`.
5. **Playback state across edits**: an edit must not reset the song's practice settings (tone, mute, loop) the way opening a song does. Test: Task 7 `an edit keeps the practice settings`.

---

### Task 0: Notation above tab, with staff toggles

The `ScoreTab` profile in alphaTab 1.6.1 draws the staves each staff's own flags allow (`showStandardNotation`, `showTablature`; `ScoreBarRendererFactory.canCreate`), so a Guitar Pro file saved with notation hidden shows tab only.

**Files:**
- Create: `engine/src/staves.ts`, `engine/test/staves.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/src/main.ts`, `lib/engine/protocol.dart`, `lib/engine/engine_bridge.dart`, `lib/features/playback/practice_settings.dart`, `lib/features/playback/playback_cubit.dart`, `lib/features/score/track_info_panel.dart`, `lib/l10n/app_en.arb`
- Test: `test/unit/engine/engine_bridge_test.dart`, `test/unit/features/playback/practice_store_test.dart`, `test/unit/features/playback/playback_cubit_test.dart`, `test/widget/score/track_info_panel_test.dart`

**Interfaces:**
- Produces (engine):
  - `showNotationAndTab(score: Score): void` sets both flags on the first staff of every track that has strings.
  - `setStaves(score: Score, staves: StaffView[]): void`, where `type StaffView = { index: number; notation: boolean; tab: boolean }` (in `protocol.ts`).
- Produces (protocol): request `setStaves` with `{ staves: StaffView[] }`, which applies them and re-renders once.
- Produces (Dart):
  - `class StaffView { index, notation, tab }` with `toJson`, and `EngineBridge.setStaves(List<StaffView>)`.
  - `TrackPractice` gains `showNotation` and `showTab` (both default true, stored in `practice.json`).
  - `PlaybackCubit.setStaffView(int track, {required bool notation, required bool tab})`.

- [ ] **Step 1: Write the failing tests.**
  - `staves.test.ts`:
    - `opens every string track with notation and tab`: a fixture whose first track has `showStandardNotation = false` and whose second has `showTablature = false` → after `showNotationAndTab`, both flags are true on both; a percussion track is untouched.
    - `setStaves hides what is asked`: `setStaves(score, [{ index: 0, notation: false, tab: true }])` → track 0 `showStandardNotation` false, `showTablature` true.
    - `setStaves refuses to hide both`: `{ notation: false, tab: false }` throws `a track needs notation or tab`.
  - `engine_bridge_test.dart`: `setStaves sends the views`.
  - `practice_store_test.dart`: `round-trips practice settings` also covers `showNotation: false` on track 1, and an older file without the keys reads as `true`.
  - `playback_cubit_test.dart`:
    - `opening a song sends only staff views that differ from the default`: saved track 1 `showNotation: false` → `setStaves([StaffView(1, notation: false, tab: true)])` once; with nothing saved, `setStaves` is never sent.
    - `setStaffView updates, persists and sends`.
  - `track_info_panel_test.dart`:
    - `notation toggles show the drawn track's staves`: `Standard notation` and `Tab` `FilterChip`s, both selected by default.
    - `turning one off calls the cubit`: tapping `Standard notation` → `setStaffView(1, notation: false, tab: true)`.
    - `the last staff on cannot be turned off`: with `showTab: false`, the `Standard notation` chip is disabled.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test; flutter test test/unit test/widget/score`
Expected: FAIL: `staves` module missing; `setStaves` and `showNotation` not defined.

- [ ] **Step 3: Implement.**
  - **Engine.** `main.ts` calls `showNotationAndTab(score)` inside the `scoreLoaded` handler, which runs before alphaTab's first render of the song. `setStaves` applies the views and calls `api.render()`.
  - **Dart.**
    - `_applyPractice` sends `setStaves` for guitar tracks whose saved view differs from both-on. It runs after `setTracks`, under the same current-song check.
    - `TrackInfoPanel` adds a `Notation` heading (l10n `notation`) with two `FilterChip`s (l10n `standardNotation`, `tab`) above Tone.

- [ ] **Step 4: Run the tests and suites**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A engine lib test
git commit -m "feat: notation above tab by default, with per-track staff toggles"
```

---

### Task 1: Edit operations on the score

**Files:**
- Create: `engine/src/editing/position.ts`, `engine/src/editing/operations.ts`, `engine/test/editing/operations.test.ts`
- Modify: `engine/test/fixtures.ts`

**Interfaces:**
- Produces:
  - `type EditPosition = { track: number; bar: number; voice: number; beat: number; string: number }` (in `protocol.ts`, so Dart can mirror it).
  - In `operations.ts`, each function changes `score` in place, calls `score.finish(settings)`, and returns the position the cursor goes to:
    - `setFret(score, at, fret)`
    - `deleteNote(score, at)`
    - `setDuration(score, at, duration, dots)`
    - `setRest(score, at)`
    - `selectVoice(score, at, voice)`
    - `move(score, at, direction: 'left' | 'right' | 'up' | 'down')`

- [ ] **Step 1: Add the fixture** `fourQuarters` to `fixtures.ts`: a 6-string track (`\tuning E4 B3 G3 D3 A2 E2`), `\ts 4 4`, bar 1 `0.6.4 2.5.4 3.4.4 r.4`, bar 2 `r.1`.

- [ ] **Step 2: Write the failing tests** in `operations.test.ts` (`const at = (bar, beat, string = 1, voice = 0) => ({ track: 0, bar, voice, beat, string })`):
  - `setFret puts a note on a rest`: `setFret(s, at(0, 3, 2), 5)` → beat 3 is not a rest, has one note `string 2, fret 5`.
  - `setFret replaces the fret on a string that has a note`: `setFret(s, at(0, 0, 1), 3)` → beat 0's string-1 note has fret 3, still one note.
  - `deleting the only note leaves a rest`: `deleteNote(s, at(0, 0, 1))` → beat 0 `isRest`.
  - `setDuration changes the beat`: `setDuration(s, at(0, 0), 8, 1)` → beat 0 is `Duration.Eighth` with one dot.
  - `setRest clears the beat's notes`: `setRest(s, at(0, 1))` → beat 1 `isRest`, duration unchanged.
  - `moving right goes to the next beat, then the next bar`: from `at(0, 2)` → `at(0, 3)`; from `at(0, 3)` → `at(1, 0)`.
  - `moving right from a bar that is not full adds a beat`: after `setDuration(s, at(0, 3), 8, 0)`, from `at(0, 3)` → `at(0, 4)`, a new eighth rest.
  - `moving right from the last beat appends a bar`: from `at(1, 0)` → `at(2, 0)`; `score.masterBars.length === 3`, the new bar's time signature is 4/4, and its voice 0 is one whole rest.
  - `moving up and down changes string within the track`: from `at(0, 0, 6)`, `up` stays at 6 (the top string of 6); from `at(0, 0, 1)`, `down` stays at 1.
  - `moving left from the first beat goes to the previous bar's last beat`: from `at(1, 0)` → `at(0, 3)`; from `at(0, 0)` stays.
  - `selectVoice creates an unused voice with one whole rest`: `selectVoice(s, at(0, 0), 1)` → bar 0 has 2 voices, and voice 1 has one whole-rest beat; the position is `at(0, 0, 1, 1)`.
  - `frets outside 0-24 are refused`: `setFret(s, at(0, 0), 25)` throws `fret 25 out of range`.

- [ ] **Step 3: Run them to verify they fail**

Run: `npm --prefix engine test`
Expected: FAIL: `../src/editing/operations` not found.

- [ ] **Step 4: Implement `operations.ts`.**
  - **Beats.** New beats are built with `new model.Beat()` and added with `voice.addBeat` or `voice.insertBeat(after, beat)`. A new beat is a rest of the cursor beat's duration, or a whole rest in a new bar.
  - **Bars.** A new bar is a `model.MasterBar`, whose time signature is copied from the previous one, plus one `model.Bar` per staff of every track. Each bar has one voice holding a single whole rest; extra voices are `isEmpty`.
  - **Full or not.** "Not full" means the voice's beats sum to less than `masterBar.calculateDuration()`, with `beat.playbackDuration` after `score.finish`.
  - **Clamping.** Positions are clamped to the track's string count and to existing beats.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`
Expected: all pass; no type errors.

- [ ] **Step 6: Commit**

```bash
git add engine
git commit -m "feat(engine): edit operations on the score"
```

---

### Task 2: Bar check and undo history

**Files:**
- Create: `engine/src/editing/bar_check.ts`, `engine/src/editing/history.ts`, `engine/test/editing/bar_check.test.ts`, `engine/test/editing/history.test.ts`

**Interfaces:**
- Consumes: Task 1's operations and fixture.
- Produces:
  - `type BarIssue = { bar: number; voice: number; ticksOff: number }`, where a negative number means short.
  - `checkBars(score: Score, track: number): BarIssue[]`
  - `describeOff(ticksOff: number): string`
  - `class History { constructor(limit = 100); record(score: Score): void; undo(current: Score): Score | null; redo(current: Score): Score | null; clear(): void; get canUndo(): boolean; get canRedo(): boolean }`. `record` stores the state before an edit; `undo` returns the state to restore and keeps `current` for redo.

- [ ] **Step 1: Write the failing tests.**
  - `bar_check.test.ts`:
    - `a full bar has no issue`: `fourQuarters` → `[]`.
    - `a short bar reports how much is missing`: after `setDuration(s, at(0, 3), 8, 0)` → `[{ bar: 0, voice: 0, ticksOff: -480 }]`.
    - `a long bar reports how much is extra`: after `setDuration(s, at(0, 0), 2, 0)` → `ticksOff: 960`.
    - `an unused voice is not checked`: after `selectVoice(s, at(0, 0), 1)` → no issue for voice 1.
    - `describeOff`: `-480 → '⅛ short'`, `960 → '¼ long'`, `-720 → '3/16 short'`, `1920 → '½ long'`, `-160 → '1/24 short'`.
  - `history.test.ts`:
    - `undo restores the state before the edit and redo brings the edit back`: record, `setFret` to 9, `undo` → beat 0 fret 0; `redo` → fret 9.
    - `a new edit after undo drops the redo steps`.
    - `keeps at most the limit`: with `new History(2)`, three records → two undos possible, then `undo` returns null.
    - `a restored score is independent of the history`: changing the restored score doesn't change the next undo.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test`
Expected: FAIL: modules not found.

- [ ] **Step 3: Implement.**
  - `checkBars` compares each used voice's summed `playbackDuration` with `masterBar.calculateDuration()`.
  - `describeOff` reduces `|ticks| / 3840` to a fraction and uses `½ ¼ ¾ ⅛ ⅜ ⅝ ⅞` where they exist.
  - `History` stores `JsonConverter.scoreToJsObject` snapshots and rebuilds them with `jsObjectToScore(snapshot, settings)`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add engine
git commit -m "feat(engine): bar check and undo history"
```

---

### Task 3: Tap to bar, beat and string; new songs

**Files:**
- Create: `engine/src/editing/hit_test.ts`, `engine/src/editing/new_song.ts`, `engine/test/editing/hit_test.test.ts`, `engine/test/editing/new_song.test.ts`

**Interfaces:**
- Produces:
  - `type Hit = { track: number; bar: number; beat: number; string: number | null }`, where `string` is null for a tap on the notation staff.
  - `hitTest(renderer: { layout: unknown; boundsLookup: BoundsLookup | null }, track: number, x: number, y: number): Hit | null`. It finds the beat through `boundsLookup.getBeatAtPos`, and the string from the nearest line of the `TabBarRenderer` for that bar. The line's y is `system.y + staff.y + renderer.y + renderer.getLineY(line)`, and string = string count − line.
  - `type NewSongOptions = { title: string; tuning: number[] /* MIDI, top string first */; tempo: number; numerator: number; denominator: number }` (in `protocol.ts`).
  - `newSong(options: NewSongOptions): Score`: one guitar track named `Guitar` (program 27, Clean), four bars of whole rests, built through `AlphaTexImporter`.

- [ ] **Step 1: Write the failing tests.**
  - `hit_test.test.ts` renders `fourQuarters` headless (`settings.core.engine = 'svg'`, `enableLazyLoading = false`, `ScoreTab`, `ScoreRenderer`, width 800, awaiting `renderFinished`). For each test it reads the target line's y and beat x from the layout and bounds, the way the code does:
    - `a tap on a tab line gives that string`: on the top line over beat 1 → `{ track: 0, bar: 0, beat: 1, string: 6 }`.
    - `a tap between lines gives the nearer string`: 3 units below line 2 (the third from the top) → string 4.
    - `a tap on the notation staff gives the beat with no string change`: on the score staff over beat 2 → `beat: 2`, `string: null`.
    - `a tap outside the score gives null`: `(5, 5)` → `null`.
  - `new_song.test.ts`:
    - `creates the tuning, tempo and time signature asked for`: 7 strings `[64, 59, 55, 50, 45, 40, 35]`, tempo 140, 6/8 → `staves[0].tuning` equals it, `score.tempo === 140`, `masterBars[0].timeSignatureNumerator === 6`, 4 bars, and every bar's voice 0 is a single rest.
    - `the title becomes the song title`.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test`
Expected: FAIL: modules not found.

- [ ] **Step 3: Implement** both files. `hitTest` only reads `layout._systems`, `staves[].staves[]`, `barRenderers[]` and `getLineY`. Each internal name it relies on gets a one-line comment that names alphaTab 1.6.1.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add engine
git commit -m "feat(engine): tap to string and new songs"
```

---

### Task 4: Editing over the bridge

**Files:**
- Create: `engine/src/editing/overlay.ts`
- Modify: `engine/src/protocol.ts`, `engine/src/main.ts`, `engine/src/mixer.ts`, `engine/index.html`, `lib/engine/protocol.dart`, `lib/engine/engine_bridge.dart`
- Test: `engine/test/mixer.test.ts`, `test/unit/engine/engine_bridge_test.dart`, `test/unit/engine/protocol_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces (protocol):
  - `type EditCommand = { op: 'setFret'; fret: number } | { op: 'deleteNote' } | { op: 'setDuration'; duration: number; dots: number } | { op: 'setRest' } | { op: 'selectVoice'; voice: number } | { op: 'move'; direction: 'left' | 'right' | 'up' | 'down' } | { op: 'place'; position: EditPosition }`.
  - `type EditState = { position: EditPosition; issues: BarIssue[]; canUndo: boolean; canRedo: boolean; song: SongSummary; edited: boolean }`, where `edited` is true when the song changed.
  - Requests: `edit` with `{ command: EditCommand }` → `EditState`; `undo` and `redo` → `EditState`; `newSong` with `NewSongOptions` → `SongSummary`; `exportGp` → `{ base64: string }`.
  - Event `tapped` with `{ position: EditPosition }`, posted for a tap on the drawn track.
- Produces (Dart): mirrors `EditPosition`, `BarIssue`, `EditState` and `NewSongOptions`, plus the bridge methods `edit(EditCommand)`, `undo()`, `redo()`, `newSong(NewSongOptions)` and `exportGp() → Future<Uint8List>`. `EditCommand` is a sealed class with one subclass per op and a `toJson`.
- Produces (engine): `Mixer.regenerate(load: () => void = () => api.loadMidiForScore()): Promise<void>`. It is the existing MIDI reload, now public: it keeps position, playing state, loop and mix around `load`, which must lead to one `midiLoaded`.

- [ ] **Step 1: Write the failing tests.**
  - `mixer.test.ts`: `regenerate keeps position, mixer and loop`, built like `a program change keeps position, mixer and loop`, but calling `regenerate()` with no program change. Add `regenerate runs the load it is given`: `regenerate(load)` with a spy that calls the fake's `loadMidiForScore` → the spy runs once, `loadMidi` once, and the position is kept.
  - `engine_bridge_test.dart`: `edit sends the command and parses the edit state`: `edit(const SetFret(5))` sends `{type: 'edit', payload: {command: {op: 'setFret', fret: 5}}}`, and a reply with a position, one issue, `canUndo: true` and a song parses to those values. `exportGp decodes base64`: a reply `{base64: 'AQID'}` gives `[1, 2, 3]`.
  - `protocol_test.dart`: `parses an edit state`.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test; flutter test test/unit/engine`
Expected: FAIL: `regenerate` not a function; `edit` not defined.

- [ ] **Step 3: Implement the engine.**
  - **Rendering.** Set `settings.core.useWorkers = false`, so `api.renderer.layout` exists on the page for `hitTest`.
  - **The edit cycle.** The engine keeps a `position: EditPosition` (bar 0, beat 0, string 1, voice 0 on each open and new song) and a `History`. `edit` runs `history.record(api.score)` before any op that changes the song (every op except `move` and `place`), then the op. It then calls `api.render()`, then `mixer.regenerate()` when the song changed, and replies with `checkBars`, the history flags, `describeOpened(api.score)` and the new position. `undo` and `redo` restore with `mixer.regenerate(() => api.renderScore(restored, [track]))`, since `renderScore` of a new score object reloads the MIDI itself.
  - **Taps.** A `click` listener on `#score` runs `hitTest` on the drawn track and posts `tapped`, keeping the current string when `string` is null and the current voice. alphaTab's own click still seeks playback.
  - **Overlays.** `overlay.ts` draws `div.dt-edit-cursor` (a 3 px tall accent bar under the cursor's fret position, on its tab line) and `div.dt-bar-issue` (a red tint over the bar's `MasterBarBounds.visualBounds`, with the `describeOff` text in `data-msg`). It redraws after every `postRenderFinished`, after every edit reply and on `tapped`. Add the CSS for both to `index.html`, matching the mockup: `rgba(230, 60, 60, .12)` tint, `#c0392b` 8 pt bold label at the top right.
  - **Export and new songs.** `exportGp` returns `Gp7Exporter` bytes as base64. `newSong` loads `newSong(options)` with `api.renderScore` and replies like `open`.
  - **Open.** `open` clears the history.

- [ ] **Step 4: Implement the Dart side**: the mirrored types and bridge methods. `EditCommand` subclasses: `SetFret(fret)`, `DeleteNote()`, `SetDuration(duration, dots)`, `SetRest()`, `SelectVoice(voice)`, `Move(direction)`, `Place(position)`.

- [ ] **Step 5: Run the tests and suites**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A engine lib test
git commit -m "feat: editing commands, undo and taps over the engine bridge"
```

---

### Task 5: Editor state

**Files:**
- Create: `lib/features/editor/editor_cubit.dart`
- Modify: `lib/features/score/score_cubit.dart`, `lib/features/playback/playback_cubit.dart`, `lib/core/dependency_injection.dart`, `lib/main.dart`
- Test: `test/unit/features/editor/editor_cubit_test.dart`, `test/unit/features/score/score_cubit_test.dart`, `test/unit/features/playback/playback_cubit_test.dart`

**Interfaces:**
- Consumes: Task 4's bridge.
- Produces:
  - `ScoreState` gains `final int openId` (incremented by each successful `open` or `create`) and `ScoreCubit.applyEdit(SongSummary song)`, which replaces `song` and keeps `openId`, `path` and the drawn track.
  - `ScoreCubit.moveTo(String path)` changes `path` only.
  - `ScoreCubit.create(NewSongOptions options, String path)` calls `engine.newSong`, then emits a new song at `path`.
  - `PlaybackCubit` treats a new `openId` as a new song, replacing its object-identity check, and follows `moveTo` by saving the current practice under the new path.
  - `class EditorState { final EditPosition? position; final List<BarIssue> issues; final bool canUndo; final bool canRedo; final int duration; final int dots; }`, with defaults: no position, duration 4, dots 0.
  - `class EditorCubit extends Cubit<EditorState> { EditorCubit({required EngineBridge engine, required ScoreCubit score}); Future<void> command(EditCommand c); Future<void> undo(); Future<void> redo(); Future<void> chooseDuration(int duration); Future<void> chooseDots(int dots); Stream<void> get edited; }`
    - `chooseDuration` and `chooseDots` remember the choice and send `SetDuration` for the cursor's beat.
    - `edited` fires after each reply with `edited: true`.
    - It listens for `tapped` events and sends `Place`.

- [ ] **Step 1: Write the failing tests.**
  - `editor_cubit_test.dart` (mocked engine):
    - `a command updates position, issues and history flags` from an `EditState` reply.
    - `an edited reply updates the score's song without a new open`: `score.state.openId` unchanged, `song` replaced.
    - `a tap places the cursor`: event `tapped {position}` → `engine.edit(Place(position))`.
    - `choosing a note value changes the cursor's beat`: `chooseDuration(8)` → `SetDuration(8, 0)` sent; `state.duration == 8`.
    - `edited fires only for edits that change the song`: a `Move` reply with `edited: false` doesn't fire.
    - `opening a song clears the cursor`: a new `openId` → `position` null, `canUndo` false.
  - `score_cubit_test.dart`: `each open has a new openId`; `applyEdit keeps the openId and the drawn track`; `moveTo changes only the path`.
  - `playback_cubit_test.dart`:
    - `an edit keeps the practice settings`: after `setMute(1, on: true)`, `score.applyEdit(newSongObject)` → `state.practice.tracks[1]!.mute` still true, and `setTracks` not sent again.
    - `moving the song saves its practice under the new path`: `moveTo('a (DuoScore).gp')` → `practice.load('a (DuoScore).gp')` has track 1 muted.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/unit/features`
Expected: FAIL: `editor_cubit.dart` not found; `openId` not defined.

- [ ] **Step 3: Implement**, and register `EditorCubit` in DI and `main.dart`.

- [ ] **Step 4: Run the tests and suite**

Run: `flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: editor state, and edits that keep the open song"
```

---

### Task 6: Fret pad

**Files:**
- Create: `lib/features/editor/fret_entry.dart`, `lib/features/editor/fret_pad.dart`
- Modify: `lib/features/score/track_info_panel.dart`, `lib/l10n/app_en.arb`
- Test: `test/unit/features/editor/fret_entry_test.dart`, `test/widget/editor/fret_pad_test.dart`

**Interfaces:**
- Consumes: `EditorCubit.command`.
- Produces: `class FretEntry { FretEntry({Duration window = const Duration(milliseconds: 800), DateTime Function() now = DateTime.now}); int digit(int d); void reset(); }`. `digit` returns the fret to set. A second digit within `window` after a `1` or `2` makes 10–24 when the result is at most 24; otherwise it starts a new fret. `class FretPad extends StatelessWidget`.

- [ ] **Step 1: Write the failing tests.**
  - `fret_entry_test.dart` (a fake clock):
    - `one digit is that fret`: `digit(7)` → 7.
    - `two quick digits make a two-digit fret`: `digit(1)`, then `digit(2)` 300 ms later → 12.
    - `a second digit past 24 starts a new fret`: `digit(2)`, then `digit(7)` → 7.
    - `a digit after the window starts a new fret`: `digit(1)`, then `digit(5)` 900 ms later → 5.
    - `a third quick digit starts again`: `1`, `2`, `3` quickly → 3.
  - `fret_pad_test.dart` (`MockCubit<EditorState>`):
    - `digits set the fret`: tap `7` → `command(SetFret(7))`.
    - `the arrows move the cursor`: tap the `Next beat` tooltip → `command(Move('right'))`; `String up` → `Move('up')`.
    - `delete removes the note`: tap the `Delete note` tooltip → `command(DeleteNote())`.
    - `the pad is disabled without a cursor`: `position: null` → tapping `7` sends nothing.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/unit/features/editor test/widget/editor`
Expected: FAIL: files not found.

- [ ] **Step 3: Implement.** `FretPad` is a 4-column grid as in the mockup:
  - **Keys:** digits `1`–`9` and `0`, a ⌫ key, and four arrow keys: ← and → move a beat, ↑ and ↓ move a string. Tooltips come from new l10n keys: `deleteNote`, `previousBeat`, `nextBeat`, `stringUp`, `stringDown`.
  - **Size:** each key is at least `AccessibleSizes.minTouchTarget` tall.
  - **Placement:** it sits in `TrackInfoPanel` below Tone, under a `Fret` heading (l10n `fret`), and is shown only while a song is open.

- [ ] **Step 4: Run the tests and suite**

Run: `flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: fret pad with two-digit frets and cursor keys"
```

---

### Task 7: Palette

**Files:**
- Create: `lib/features/editor/palette.dart`, `lib/features/editor/smufl.dart`
- Modify: `lib/features/score/score_page.dart`, `lib/presentation/workspace/workspace_layout.dart`, `lib/features/settings/settings_cubit.dart`, `pubspec.yaml`, `lib/l10n/app_en.arb`
- Test: `test/widget/editor/palette_test.dart`, `test/widget/workspace/workspace_layout_test.dart`, `test/widget/score/score_page_test.dart`, `test/unit/features/settings/settings_cubit_test.dart`

**Interfaces:**
- Consumes: `EditorCubit` (`chooseDuration`, `chooseDots`, `command(SetRest())`, `command(SelectVoice(n))`, `undo`, `redo`, `state`).
- Produces:
  - `class Palette extends StatelessWidget`.
  - `WorkspaceLayout` gains `paletteCollapsed` and `onTogglePalette`, mirroring the track panel. The icons are `keyboard_double_arrow_left` to collapse and `_right` to expand; the button sits against the bar when the bar is on the leading edge, otherwise at the palette's top left.
  - `AppSettings.paletteCollapsed` and `SettingsCubit.setPaletteCollapsed({required bool collapsed})`.
  - `smufl.dart` names the Bravura code points used:
    - notes: whole ``, half ``, quarter ``, 8th ``, 16th ``, 32nd ``, 64th ``;
    - rests: whole ``, half ``, quarter ``, 8th ``, 16th ``, 32nd ``, 64th ``;
    - augmentation dot ``.
  - `pubspec.yaml` declares the font family `Bravura` from `assets/engine/alphatab/font/Bravura.otf`.

- [ ] **Step 1: Write the failing tests.**
  - `palette_test.dart` (`MockCubit<EditorState>`):
    - `groups for voice, note value, rests and dots`: headings `Voice`, `Note value`, `Rests`, `Dots`.
    - `marks the chosen note value`: `duration: 8` → the eighth-note chip is selected (`ChoiceChip.selected`).
    - `a note value sets the beat's duration`: tap the semantics label `Quarter note` → `chooseDuration(4)`.
    - `a rest sets the beat to a rest of that value`: tap `Eighth rest` → `chooseDuration(8)`, then `command(SetRest())`.
    - `dots toggle`: with `dots: 1`, tap `Dot` → `chooseDots(0)`; tap `Double dot` → `chooseDots(2)`.
    - `voices select the voice`: tap `Voice 2` → `command(SelectVoice(1))`.
    - `undo and redo follow the history`: `canUndo: false` → the Undo button is disabled; with `canUndo: true`, tapping it calls `undo()`.
  - `workspace_layout_test.dart`: `a collapsed palette gives its width to the score` and `the palette button toggles the palette`, like the track panel tests.
  - `settings_cubit_test.dart`: `persists each setting` also covers `paletteCollapsed`.
  - `score_page_test.dart`: `editing is off when the window is narrow`: at width 600, no `Palette` and no `FretPad`, and `Make DuoScore wider to edit` is shown.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/widget test/unit/features/settings`
Expected: FAIL: `palette.dart` not found; `paletteCollapsed` not defined.

- [ ] **Step 3: Implement.**
  - **The palette** is a `ListView` of groups (heading, then a `Wrap` of `ChoiceChip`s or icon buttons):
    - Voice `1`–`4`;
    - Note value, whole to 64th, as Bravura glyphs;
    - Rests, whole to 64th, as Bravura glyphs;
    - Dots: dot, double dot.

    Every glyph chip has a semantics label from l10n (`wholeNote` … `sixtyFourthNote`, `wholeRest` … `sixtyFourthRest`, `dot`, `doubleDot`, `voiceN` with a `{number}` placeholder). Undo and Redo (`Icons.undo`/`Icons.redo`, l10n `undo`/`redo`) sit in its first row.
  - **The score page.** `ScorePage` passes `palette: const Palette()` when a song is open, plus its collapse state from `SettingsCubit`. In the collapsed (narrow) layout, neither the palette nor the fret pad is shown.

- [ ] **Step 4: Run the tests and suite**

Run: `npm --prefix engine run build && flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test pubspec.yaml
git commit -m "feat: notation palette with voices, note values, rests and dots"
```

---

### Task 8: Saving and new songs

**Files:**
- Create: `lib/features/editor/song_saver.dart`, `lib/features/editor/owned_files.dart`, `lib/features/editor/new_song_dialog.dart`, `lib/features/editor/tuning_presets.dart`
- Modify: `lib/features/library/library_page.dart`, `lib/main.dart`, `lib/core/dependency_injection.dart`, `lib/l10n/app_en.arb`
- Test: `test/unit/features/editor/song_saver_test.dart`, `test/unit/features/editor/tuning_presets_test.dart`, `test/widget/editor/new_song_dialog_test.dart`, `test/unit/features/score/score_cubit_test.dart`

**Interfaces:**
- Consumes: `EditorCubit.edited`, `EngineBridge.exportGp`, `ScoreCubit.moveTo`/`create`, `uniqueDestination`, `JsonFile`, `LibraryCubit.refresh`.
- Produces:
  - `class OwnedFiles { OwnedFiles(JsonFile file); Future<bool> owns(String path); Future<void> add(String path); }`
  - `class SongSaver { SongSaver({required Directory documents, required EngineBridge engine, required ScoreCubit score, required OwnedFiles owned, required Future<void> Function() onSaved, Duration delay = const Duration(seconds: 1)}); void schedule(); Future<void> saveNow(); Future<String> createSong(NewSongOptions options); }`
    - `schedule` is debounced.
    - `saveNow` writes the export to the score's path when it is owned. Otherwise it claims `<name> (DuoScore).gp` beside it, writes there, records it in `owned`, and calls `score.moveTo`.
    - `createSong` claims `<title>.gp` with `uniqueDestination`, records it, calls `score.create` and saves.
  - `List<TuningPreset> tuningPresets(int strings)`, where `class TuningPreset { final String name; final List<int> tuning; }` and `tuning` is top string first.
  - `NewSongDialog` returns `NewSongOptions`; Library's `New song` button opens it, then calls `SongSaver.createSong` and switches to the Editor tab.

- [ ] **Step 1: Write the failing tests.**
  - `song_saver_test.dart` (temp Documents; a mocked engine whose `exportGp` returns `[1, 2, 3]`; a real `ScoreCubit` on a mocked engine, opened at `a.gp`):
    - `the first edit of an opened file writes a copy beside it`: `saveNow()` → `a (DuoScore).gp` holds `[1, 2, 3]`; `a.gp` untouched; `score.state.path == 'a (DuoScore).gp'`; `onSaved` called.
    - `later saves write the copy`: a second `saveNow()` with export `[4]` → the copy holds `[4]`, and no `a (DuoScore) (2).gp` exists.
    - `an existing copy name gets a counter`: an existing `a (DuoScore).gp` (not owned) → writes `a (DuoScore) (2).gp`.
    - `a file the app did not create is never written`: open `b (DuoScore).gp`, not owned → `saveNow` writes `b (DuoScore) (DuoScore).gp`.
    - `schedule saves once after the delay`: three `schedule()` calls 100 ms apart (fake async) → one export after 1 s.
    - `createSong saves a new song under its title`: `createSong(title: 'Riff')` → `Riff.gp` exists and is owned; `score.state.path == 'Riff.gp'`.
  - `score_cubit_test.dart`: `an engine restart reopens the saved copy`: open `a.gp`, `moveTo('a (DuoScore).gp')`, a `ready` event → `engine.open('a (DuoScore).gp')`.
  - `tuning_presets_test.dart`:
    - `6 strings start with Standard E` (`[64, 59, 55, 50, 45, 40]`) and include `Drop D` (`[64, 59, 55, 50, 45, 38]`);
    - `7 strings include Standard B` (`[64, 59, 55, 50, 45, 40, 35]`);
    - `8 strings include Standard F♯` (`[64, 59, 55, 50, 45, 40, 35, 30]`);
    - `every preset has as many notes as strings`.
  - `new_song_dialog_test.dart`:
    - `creates with the chosen strings, tuning, tempo and time signature`: enter title `Riff`, choose `7 strings`, the `Standard A` preset, tempo `140` and `6/8`, tap `Create` → pops `NewSongOptions(title: 'Riff', tuning: Standard A, tempo: 140, numerator: 6, denominator: 8)`.
    - `a custom tuning sets each string`: choose `Custom`, set string 6 to `D` → the tuning's last note is 38.
    - `Create needs a title`: an empty title → `Create` disabled.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/unit/features/editor test/widget/editor test/unit/features/score`
Expected: FAIL: files not found.

- [ ] **Step 3: Implement.**
  - **Wiring.** `SongSaver` subscribes to `EditorCubit.edited` (wired in DI), and `onSaved` refreshes the library. `OwnedFiles` stores Documents-relative paths in `<Application Support>/owned.json`. `ScoreCubit._reopen` uses the current `path`, which `moveTo` updated.
  - **The dialog.** The title field; strings `6`/`7`/`8` as a `SegmentedButton`; a tuning dropdown of `tuningPresets(strings)` plus `Custom`, where custom shows one dropdown per string with the 12 note names over the octaves the preset spans. Then tempo (30–300) and time signature: `4/4`, `3/4`, `6/8`, `7/8`, `5/4`, `12/8`, or `Custom` with numerator 1–32 and denominator 1, 2, 4, 8, 16 or 32.
  - **Library.** Enable `New song` in `LibraryPage`. New l10n keys for every label.

- [ ] **Step 4: Run the tests and suite**

Run: `flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: autosave into a DuoScore copy, and new songs from the library"
```

---

### Task 9: Simulator acceptance

No new code unless a check fails; a failure goes through superpowers:systematic-debugging, and its fix needs a test that failed first.

- [ ] **Step 1: Build and install**

Run: `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted dev.edbrsk.duoscore`
Expected: build succeeds; the app launches.

- [ ] **Step 2: Owner checks**, reported back in one message:
  0. **Open Collateral Damage**: notation is drawn above the tab. Turning Standard notation off in the track panel leaves tab only, and the choice is still there after a relaunch.
  1. **New song**, 7 strings, Standard A, 140, 6/8: the editor opens with four empty bars in 6/8, notation over a 7-line tab.
  2. **Tap a string** in bar 1: the cursor shows on that string. Type `5`, then `1` and `2` quickly: the frets read 5, then 12, and the notation updates.
  3. **Note values and dots**: an eighth, then a dotted quarter. A bar that's too long or too short turns red with its amount; filling it right clears the red.
  4. **Voice 2**: notes go into a second voice, drawn with stems the other way.
  5. **Undo and redo** step back and forth through those edits.
  6. **Open Collateral Damage** and change one fret: `Collateral Damage (DuoScore).gp` appears in the library, and the original is untouched (open it in Guitar Pro 8).
  7. **The copy opens in Guitar Pro 8** with the change.
  8. **Edit while playing**: playback continues from the same spot with the change audible.
  9. **Collapse the palette and the track panel**: the sheet widens. In narrow Split View, the palette and the fret pad disappear and "Make DuoScore wider to edit" shows.
  10. **Re-render time** after an edit on Collateral Damage feels immediate (note the delay if not).

- [ ] **Step 3: Record the results** in the ledger, one line per check, and fix any failure as described above.
