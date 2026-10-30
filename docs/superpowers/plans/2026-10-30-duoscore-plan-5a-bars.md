# DuoScore Plan 5a: Bars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Edit bars the way Guitar Pro does:
- set a time signature, tempo marking, key signature and clef on any bar;
- insert, delete, copy and paste bars.

**Architecture:**
- **Bar properties** (`engine/src/editing/bars.ts`) change alphaTab's `MasterBar` and `Bar` fields from the cursor bar until the next change.
- **Bar structure** (`engine/src/editing/bar_structure.ts`) splices `MasterBar`s and `Bar`s and relinks them, with `Score.rebuildRepeatGroups()`.
- **Copy** keeps a pruned JSON copy of the copied bars, so pasting rebuilds real alphaTab objects with every technique intact.
- **Commands** run through `runCommand` as before. The Bar palette group opens menus like the bend menu.

**Tech Stack:** as Plan 4. alphaTab 1.6.1 fields and methods used:
- `MasterBar`: `timeSignatureNumerator`, `timeSignatureDenominator`, `timeSignatureCommon`, `tempoAutomations`, `section`;
- `Automation.buildTempoAutomation`;
- `Bar`: `keySignature`, `keySignatureType`, `clef`, `clefOttava`;
- `Score`: `tempo`, `rebuildRepeatGroups()`;
- `JsonConverter.scoreToJson` and `jsonToScore`; `tickCache.masterBars`.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`. The relevant parts:
- Editor › Palette groups (Bar);
- "Time signatures: a change applies from its bar until the next change";
- Bar check;
- "Bar editing: insert, delete, copy and paste bars";
- Undo.

**Branch:** `plan-5a-bars`, from `main`.

## Roadmap

| Plan | Delivers |
|---|---|
| 5a Bars (this) | time signature, tempo marking, key signature and clef per bar; insert, delete, copy and paste bars |
| 5b Song structure | repeats, alternate endings, segno/coda |
| 5c Tracks | the mixer; adding, removing, reordering and renaming guitar tracks |
| 6 Retune and export | retuning, automatic fingering, `.gp` and PDF export, share sheet |

## Global Constraints

Plans 1–4's Global Constraints all apply. In addition:

- **From here until the next change.** A time signature, key signature or clef set on a bar applies to that bar and to the bars after it that had the same old value, stopping at the next bar that differs.
- **Scope of each property:**
  - Time signatures and tempo belong to the bar of the whole song (`MasterBar`).
  - A key signature is set on every track's bar, because the `.gp` writer reads it from the first track.
  - A clef is set on the cursor track only.
- **Notes are never moved or dropped by a property change.**
  - A bar that held only rests (every voice made only of rests or unused beats) is refilled to fit its new time signature: voice 0 gets fitting rests, and other voices become unused.
  - A bar with notes keeps them, and the bar check flags it when it no longer fits.
- **Values:**
  - **Time signature:** numerator 1–32; denominator 1, 2, 4, 8, 16 or 32. The palette's presets are 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8 and 12/8.
  - **Tempo:** 30–300 BPM, the same range as New song. A tempo marking sits at the start of its bar (`ratioPosition` 0). The first bar always has a tempo, and setting it also sets `score.tempo`.
  - **Key signature:** −7 to 7 (flats to sharps), plus major or minor.
  - **Clef:** `treble` (G2, the guitar's; the staff's display transposition puts guitar notation an octave above the sound) or `bass` (F4). Any other clef reads as null.
- **Insert** puts a new bar before the cursor bar, in every track. It takes the cursor bar's time signature, key signature and clef, and is filled with rests (voice 0 fitting rests, the other voices unused). Inserted before the first bar, it takes over the first bar's tempo marking.
- **Delete** removes the cursor bar from every track. A tempo marking on the deleted bar moves to the next bar unless that bar has its own. The song's only bar is never deleted.
- **Copy** takes the bars of the loop selection when the cursor bar is inside it, and otherwise the cursor bar, from the cursor track. The clipboard survives opening another song.
- **Paste** replaces the contents of the cursor track's bars from the cursor bar on, adding bars at the end when needed. It never changes those bars' time signature, tempo, key or clef. Notes on strings the track lacks are dropped.
- **The loop and bar edits:** insert, delete, a time signature change and a paste that adds bars all shift the song's ticks. Each of them clears the loop and reports `rangeChanged` with a null range.
- **New beats, notes, voices and bars** take their ids from `idSource`. Every voice count stays equal across a staff, because `Voice.chain` needs it.

## Review Focus

1. **A time signature change over bars that hold notes** keeps every note and flags the bars that don't fit. Test: Task 1 `a time signature change keeps the notes and the bar check flags the bars`.
2. **Deleting a bar that has a tempo change** keeps the later bars at that tempo. Test: Task 2 `deleting a bar with a tempo change carries it to the next bar`.
3. **Inserting or deleting a bar in a song with several tracks** keeps every track aligned, and the result survives the `.gp` round-trip. Test: Task 2 `bar edits keep every track aligned and survive the .gp round-trip`.
4. **Pasting into a track with fewer strings or fewer voices** doesn't crash, and voice counts stay equal. Tests: Task 2 `paste drops notes on strings the track lacks`, `paste keeps the staff's voice counts equal`.
5. **A loop set before a bar edit** is cleared rather than covering other bars. Test: Task 3 `bar edits that move ticks clear the loop`.

---

### Task 1: Bar properties

**Files:**
- Create: `engine/src/editing/bars.ts`, `engine/test/editing/bars.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/test/fixtures.ts`

**Interfaces:**
- Produces (protocol):
  - `type Clef = 'treble' | 'bass'`;
  - `type BarProperties = { numerator: number; denominator: number; key: number; minor: boolean; clef: Clef | null; tempo: number; tempoChange: boolean }`, where `tempo` is the BPM in force at the bar's start, and `tempoChange` is true when this bar has its own marking (always true for bar 0).
- Produces (engine), in `bars.ts`. Each setter changes `score` in place, ends with `finishEdit` and returns the cursor position:
  - `setTimeSignature(score, at, numerator, denominator)`, which throws `time signature 0/4 out of range` for values outside the limits;
  - `setTempo(score, at, bpm: number | null)`, where null removes the bar's marking. It is a no-op on bar 0, and throws `tempo 20 out of range` outside 30–300;
  - `setKeySignature(score, at, key: number, minor: boolean)`, which throws outside −7 to 7;
  - `setClef(score, at, clef: Clef)`;
  - `barProperties(score, at): BarProperties`, a reader.
- Fixture `twoTracksThreeBars`: two 6-string guitar tracks, 4/4, `\tempo 100`. In both tracks, bar 0 holds `0.6.4 2.6.4 3.6.4 5.6.4`, and bars 1 and 2 hold `r.1`.

- [ ] **Step 1: Write the failing tests** in `bars.test.ts`, with `at(bar, beat, string)`:
  - **`a time signature runs to the next change`:**
    - On `twoTracksThreeBars`, setting bar 1 to 3/4 puts bars 1–2 at 3/4, and bar 0 stays 4/4.
    - Setting bar 2 to 6/8 and then bar 1 to 3/4 gives 4/4, 3/4, 6/8.
  - **`a time signature change keeps the notes and the bar check flags the bars`:** `setTimeSignature(at(0,0), 3, 4)` keeps bar 0's four notes, and `checkBars` reports bar 0 `ticksOff` 960 in both tracks' checks.
  - **`bars of rests refill to the new time signature`:** after the change above, bars 1 and 2 are each one rest group adding up to 2880 ticks, and `checkBars` reports nothing for them.
  - **`a tempo marking sets that bar on`:** `setTempo(at(2,0), 140)` gives `barProperties(at(2,0))` `{ tempo: 140, tempoChange: true }`, and bar 1 reads 100 with `tempoChange: false`. `setTempo(at(2,0), null)` puts bar 2 back to 100. `setTempo(at(0,0), 90)` sets `score.tempo` to 90.
  - **`a key signature goes on every track`:** `setKeySignature(at(1,0), -3, true)` makes bars 1–2 of both tracks −3 minor, and bar 0 stays C.
  - **`a clef goes on the cursor track only`:** `setClef(at(1,0), 'bass')` makes track 0's bars 1–2 F4 Regular, and track 1 keeps its clef. `barProperties` reads `bass`.
  - **`out-of-range values are refused`:** 0/4, 4/3, 33/4, tempo 20, tempo 301, key 8.
  - **`bar properties survive the .gp round-trip`:** all four properties set on bar 2, exported with `Gp7Exporter` and reloaded, read the same `barProperties`.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test`
Expected: FAIL: `../../src/editing/bars` not found.

- [ ] **Step 3: Implement `bars.ts`.**
  - **The tempo:** the walk takes the last ratio-0 `tempoAutomations` entry at or before the bar, and falls back to `score.tempo`. Setting a tempo replaces the ratio-0 automation with `Automation.buildTempoAutomation(false, 0, bpm, 2)`.
  - **Refilling:** a rest-only bar is refilled with `restsFilling` (exported from `operations.ts`), with ids from `idSource`.

- [ ] **Step 4: Run the tests**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`
Expected: all pass.

- [ ] **Step 5: Commit** `feat(engine): time signature, tempo, key and clef per bar`

---

### Task 2: Insert, delete, copy and paste bars

**Files:**
- Create: `engine/src/editing/bar_structure.ts`, `engine/test/editing/bar_structure.test.ts`
- Modify: `engine/src/editing/operations.ts`, which exports `emptyVoice` and `ensureVoice` for reuse.

**Interfaces:**
- Consumes: Task 1's fixture.
- Produces (engine), in `bar_structure.ts`:
  - `insertBar(score, at): EditPosition`: the new bar takes the cursor bar's index, and the cursor goes to its beat 0, voice 0.
  - `deleteBar(score, at): EditPosition`: the cursor goes to the bar now at that index (the previous bar when the last bar was deleted), beat 0. It is a no-op on a song with one bar.
  - `type Clipboard = { json: string; bars: number }`: `json` is `JsonConverter.scoreToJson` of a copy of the song pruned to the copied `masterbars` and one track holding just those bars.
  - `copyBars(score, track, from, to): Clipboard`.
  - `pasteBars(score, at, clipboard): EditPosition`: the cursor goes to the cursor bar's beat 0, voice 0.
  - `relink(score)`, internal: it sets each master bar's `index`, `previousMasterBar`/`nextMasterBar`, `start` and `score`, and each staff bar's `index`, `previousBar`/`nextBar` and `staff`, then calls `score.rebuildRepeatGroups()`, then `score.finish`.

- [ ] **Step 1: Write the failing tests** in `bar_structure.test.ts`:
  - **`insert puts a bar of rests before the cursor bar`:** on bar 0, the song gets 4 bars. The new bar 0 is a whole rest in both tracks, and the old bar 0's notes are now in bar 1.
  - **`an inserted bar takes the cursor bar's time signature, key and clef`:** bar 1 at 3/4 with key −2 and bass clef gives a new bar 1 with the same values.
  - **`inserting before the first bar takes over its tempo`:** `barProperties(at(0,0)).tempo` stays 100, and bar 1 has `tempoChange: false`.
  - **`delete removes the bar from every track`:** deleting bar 0 leaves 2 bars, and bar 0 is now the old bar 1 in both tracks.
  - **`deleting a bar with a tempo change carries it to the next bar`:** with tempo 140 on bar 1, deleting bar 1 leaves the new bar 1 at 140 with a marking.
  - **`the only bar is never deleted`.**
  - **`bar edits keep every track aligned and survive the .gp round-trip`:** insert at 1, delete at 0, insert at 2. Then both tracks have equal bar counts, `idSource`-unique ids, and after `Gp7Exporter` → `ScoreLoader` the same bar count and note frets per bar.
  - **`copy and paste repeat bars`:** copy bar 0 of track 0, paste at bar 2. Bar 2's notes equal bar 0's, including a palm mute and a bend set on bar 0 before copying. Bar 0 is unchanged, and ids are unique.
  - **`paste past the end adds bars`:** copy bars 0–1, paste at bar 2, and the song has 4 bars.
  - **`paste drops notes on strings the track lacks`:** a bar of the 7-string track in `twoGuitarsAndDrums`, given notes on strings 7 and 1, is pasted into the 6-string track. The string 7 note is dropped, and the string 1 note stays.
  - **`paste keeps the staff's voice counts equal`:** a copied bar using voice 2, pasted into a one-voice track, gives every bar of that staff 2 voices.
  - **`the clipboard survives another song`:** a clipboard from one score pastes into a freshly loaded other score.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test`
Expected: FAIL: `../../src/editing/bar_structure` not found.

- [ ] **Step 3: Implement `bar_structure.ts`.**
  - **Insert and delete** splice `score.masterBars` and every `staff.bars`, then call `relink`.
  - **Paste** loads the clipboard with `JsonConverter.jsonToScore` and moves the loaded bars' `Voice` objects into the target bars, with fresh ids from `idSource` for voices, beats and notes. It sets `voice.bar`, drops notes on missing strings, pads every bar of the staff to the same voice count with `emptyVoice`, and ends with `finishEdit`.

- [ ] **Step 4: Run the tests** as in Task 1. Expected: all pass.

- [ ] **Step 5: Commit** `feat(engine): insert, delete, copy and paste bars`

---

### Task 3: Bar commands over the bridge

**Files:**
- Modify: `engine/src/protocol.ts`, `engine/src/editing/commands.ts`, `engine/src/editing/session.ts`, `engine/src/main.ts`, `lib/engine/protocol.dart`
- Test: `engine/test/editing/commands.test.ts`, `engine/test/editing/session.test.ts`, `test/unit/engine/engine_bridge_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces (protocol):
  - `EditCommand` gains:
    - `{ op: 'setTimeSignature'; numerator: number; denominator: number }`;
    - `{ op: 'setTempo'; bpm: number | null }`;
    - `{ op: 'setKeySignature'; key: number; minor: boolean }`;
    - `{ op: 'setClef'; clef: Clef }`;
    - `{ op: 'insertBar' }`, `{ op: 'deleteBar' }`, `{ op: 'copyBars' }`, `{ op: 'pasteBars' }`.
  - `EditState` gains `bar: BarProperties | null` (null without a cursor) and `canPaste: boolean`.
- Produces (engine):
  - `EditSession.command(score, command, selection: { from: number; to: number } | null = null)`. `main.ts` passes the master-bar indexes the loop covers, found through `api.tickCache.masterBars`.
  - `copyBars` copies `selection` when it contains the cursor bar, else the cursor bar, and is not an edit.
  - `movesTicks(command): boolean`, in `commands.ts`, is true for `insertBar`, `deleteBar`, `setTimeSignature` and `pasteBars`. `main.ts` clears the loop and posts `rangeChanged` after such an edit.
  - `shape` adds each bar's time signature, ratio-0 tempo, key signature and clef, so a property change counts as an edit.
- Produces (Dart):
  - commands `SetTimeSignature(int numerator, int denominator)`, `SetTempo(int? bpm)`, `SetKeySignature(int key, {required bool minor})`, `SetClef(String clef)`, `InsertBar()`, `DeleteBar()`, `CopyBars()`, `PasteBars()`;
  - `EditState` fields `barNumerator`, `barDenominator`, `barKey`, `barMinor`, `barClef` (`String?`), `barTempo`, `barTempoChange` and `canPaste`. Their defaults are 4, 4, 0, false, null, 120, false and false.

- [ ] **Step 1: Write the failing tests:**
  - **`commands.test.ts`:**
    - `bar commands are edits and undo`: each property command and insert/delete changes the song and undoes.
    - `undo brings back a deleted bar`.
    - `copy is not an edit`.
    - `setting the same time signature is not an edit`.
    - `bar edits that move ticks clear the loop`: `movesTicks` is true for exactly the four ops.
  - **`session.test.ts`:**
    - `the state tells the bar's properties and whether paste can run`.
    - `copy takes the loop's bars when the cursor is inside them`: selection {1,2} with the cursor on bar 1 gives a clipboard of 2 bars.
  - **`engine_bridge_test.dart`:** each new command serialises, and `parses an edit state` covers `bar` and `canPaste`.

- [ ] **Step 2: Run them to verify they fail.**

- [ ] **Step 3: Implement.** The clipboard lives in `EditSession`, and `open` keeps it.

- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && flutter test test/unit/engine && flutter analyze`. Expected: all pass.

- [ ] **Step 5: Commit** `feat: bar commands over the bridge`

---

### Task 4: Editor state for bars

**Files:**
- Modify: `lib/features/editor/editor_cubit.dart`
- Test: `test/unit/features/editor/editor_cubit_test.dart`

**Interfaces:**
- Consumes: Task 3's Dart types.
- Produces: `EditorState` gains `barNumerator`, `barDenominator`, `barKey`, `barMinor`, `barClef`, `barTempo`, `barTempoChange` and `canPaste`, from each reply. New `EditorCubit` methods wait for a cursor:
  - `setTimeSignature(int numerator, int denominator)`;
  - `setTempo(int? bpm)`;
  - `setKeySignature(int key, {required bool minor})`;
  - `setClef(String clef)`;
  - `insertBar()`, `deleteBar()`, `copyBars()`, `pasteBars()`.

- [ ] **Step 1: Write the failing tests:**
  - `the state follows the bar at the cursor`;
  - `bar commands send their command`;
  - `bar commands wait for a cursor`.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test --timeout 60s && flutter analyze`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: editor state for bars`

---

### Task 5: The palette's Bar groups

**Files:**
- Modify: `lib/features/editor/palette.dart`, `lib/features/editor/smufl.dart`, `lib/l10n/app_en.arb`
- Create: `lib/features/editor/bar_menus.dart` (the time signature, key signature and clef menus, and the tempo dialog)
- Test: `test/widget/editor/palette_test.dart`, `test/widget/editor/bar_menus_test.dart`

**Interfaces:**
- Consumes: Task 4.
- Produces: two groups after Dots, before Accidentals.

  **Bar group.** Every chip opens a menu or dialog and needs a cursor.

  | Chip | Label | Opens |
  |---|---|---|
  | Clef | `Smufl.gClef` U+E050 or `Smufl.fClef` U+E062, as the bar's clef | a menu of the two clefs |
  | Time signature | the bar's value as text, e.g. `6/8` | a menu with the eight presets as chips, plus a Custom row: numerator −/+ (1–32) and denominator chips 2, 4, 8, 16. Each change sends `setTimeSignature`. |
  | Key signature | the key's name, e.g. `E♭` or `Cm` | a menu with 15 key chips in circle-of-fifths order and a Major/Minor toggle. Each choice sends `setKeySignature`. |
  | Tempo | `♩ = 120` | a dialog with a BPM field (30–300, Set disabled outside the range), Set, Cancel, and Remove tempo change, which is disabled on bar 0 or when `!barTempoChange` |

  The key chips' names, flats to sharps:
  - major: C♭ G♭ D♭ A♭ E♭ B♭ F C G D A E B F♯ C♯;
  - minor: A♭m E♭m B♭m Fm Cm Gm Dm Am Em Bm F♯m C♯m G♯m D♯m A♯m.

  **Bars group:** icon chips with tooltips, all needing a cursor:
  - Insert bar (`Icons.add_box_outlined`);
  - Delete bar (`Icons.delete_outline`);
  - Copy bars (`Icons.content_copy`);
  - Paste bars (`Icons.content_paste`, disabled without `canPaste`).

- [ ] **Step 1: Write the failing tests:**
  - **`palette_test.dart`:**
    - `shows the bar groups`: headings `BAR` and `BARS`.
    - `bar chips show the bar's values`: `6/8`, `E♭`, `♩ = 90`, and the bass clef glyph.
    - `bar chips need a cursor`.
    - `paste needs a clipboard`.
    - `the bars chips send their commands`.
  - **`bar_menus_test.dart`:**
    - `a time signature preset sets it`: `6/8` sends `setTimeSignature(6, 8)`.
    - `the custom time signature steps the numerator`: from 4/4, + sends `setTimeSignature(5, 4)`.
    - `a key chip sets the key, and minor names follow the toggle`: tapping Minor then `Cm` sends `setKeySignature(-3, minor: true)`.
    - `a clef chip sets it`.
    - `the tempo dialog sets, refuses and removes`: 140 sends `setTempo(140)`; 20 leaves Set disabled; Remove sends `setTempo(null)` and is disabled on bar 0.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement**, reusing `_Group`, `_Chip`, `_Glyph` and `_Text`, and the `MenuAnchor` pattern of `_BendChip`. Every chip has an l10n tooltip.
- [ ] **Step 4: Run** `npm --prefix engine run build && flutter test --timeout 60s && flutter analyze`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: palette groups for bar properties and bar editing`

---

### Task 6: Simulator acceptance

No new code unless a check fails. A failure goes through superpowers:systematic-debugging, and its fix needs a test that failed first.

- [ ] **Step 1: Build and install**

Run: `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted dev.edbrsk.duoscore`
Expected: build succeeds; the app launches.

- [ ] **Step 2: Owner checks**, reported back in one message:
  1. On a new 4/4 song, set bar 2 to 6/8. Bars 2–4 show 6/8, and their rests fit.
  2. On bars with notes, a 3/4 change keeps the notes and tints the bars with how much they're off.
  3. A tempo marking of 160 on bar 3 shows ♩ = 160 over it, and playback speeds up there. Removing it brings back the earlier tempo.
  4. A key signature of E♭ shows three flats in every track from that bar on.
  5. A bass clef on one track redraws that track's notation and leaves the tab alone.
  6. Insert, delete, copy and paste work on single bars. Copy with a loop selected copies the looped bars, and paste past the end adds bars.
  7. Undo reverts each of these.
  8. The "(DuoScore)" copy opens in Guitar Pro 8 with the time signatures, tempos, keys, clefs and bars as set.

- [ ] **Step 3: Record the results** in the ledger, one line per check, and fix any failure as described above.
