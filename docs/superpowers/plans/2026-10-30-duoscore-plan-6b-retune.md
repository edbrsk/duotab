# DuoScore Plan 6b: Retuning and Automatic Fingering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:**
- Retune a guitar track while keeping how it sounds.
- Give strings and frets to guitar parts that have only pitches.

**Architecture:**
- **One string-choice rule** in `engine/src/editing/fingering.ts` serves both features:
  - `fingerUnstrung` runs on every opened or summarised file;
  - `retune` (`engine/src/editing/retune.ts`) is an undoable track command.
- **Marks:** both report the notes they moved or couldn't place. The session keeps those notes as marks until the next edit, and the overlay tints them amber or red on the tab.
- **Flutter** sends the command from a Retune dialog in the track panel and shows the report there. A fingered file with unplayable notes shows a SnackBar.

**Tech Stack:** as Plan 6a. alphaTab 1.6.1:
- **Strings:**
  - `Note.string` is 1-based from the lowest string;
  - `Staff.stringTuning.tunings` lists the top string first, so a note's open pitch is `tunings[tunings.length - string]`;
  - `Tuning.finish()` renames a tuning only when it is a known one, so retune sets `name = ''` first.
- **Notes without frets:** a fret-less note has `string −1` and `isPiano`, with pitch `octave * 12 + tone`. A fret-less note on a staff with a tuning crashes the tab renderer.
- **Load order:** `api.load` calls `scoreLoaded`, then builds the MIDI, then renders. The `fromFile` hook in `main.ts` therefore reaches both.
- **Links:** `score.finish` relinks ties, hammer-ons and slides along strings from their flags (`isTieDestination`, `isHammerPullOrigin`, `slideOutType` Shift or Legato), after `finishEdit` clears the pointers.
- **Chord diagrams:** `Chord.strings` lists frets from the highest string down; −1 means the string isn't played.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`:
- Goals 5;
- Retuning, steps 1–5;
- Music engine › Automatic fingering;
- Editor › Undo ("including retuning");
- Anti-goals: "Notes are silently dropped or moved during retuning without the user being told."

**Branch:** `plan-6b-retune`, from `main`.

## Global Constraints

Plans 1–6a's Global Constraints all apply. In addition:

- **Highest fret:** 24, `MAX_FRET` in `fingering.ts`. A fret is playable when it is 0–24.
- **String choice:**
  - **Cost:** `positionCost(frets, anchor)` = Σ over the notes of (fret 0 → 0, else |fret − anchor|), plus 0.1 × Σ frets, plus 10 × (span − 4) when the span exceeds 4. The span is the highest fret above 0 minus the lowest fret above 0.
  - **Anchor:** the mean fret above 0 of the nearest earlier beat in the same voice that has one. With no such beat it is 0, which favours the lowest position.
  - **Free strings:** a string is free for a note when no other note in its bar, in any voice, sits on that string over an overlapping time. Each note spans `[playbackStart, playbackStart + max(playbackDuration, 1))`.
  - **Choosing:** among assignments where every note is playable on a free string, distinct within a beat, the lowest cost wins. A tie goes to the first one found, trying each note's strings from the highest-pitched.
- **Automatic fingering:**
  - **Which tracks:** a guitar track (`isGuitar`, not percussion) is fingered when any of its notes has `string < 0`. Notes that already have a string keep it and occupy it.
  - **Tuning:** the staff's tuning, or standard E `[64, 59, 55, 50, 45, 40]` when it has none.
  - **Order:** bars in order, voices in order, beats in order.
  - **Ties:** a tie destination takes its origin's string and fret.
  - **Unplayable notes:** a note no free string can play goes on the free string, else any string, whose open pitch is nearest below it, else the lowest string. Its fret is `max(0, pitch − open)` and it is counted as unplayable. That fret can be above 24, which keeps the pitch; a note below the lowest string sounds at that string's open pitch.
  - **Staff:** the fingered staff shows notation and tab.
  - **When:** fingering runs in `summarize`, and in the open hook before `showNotationAndTab`. It isn't an edit, so it makes no copy and no undo step.
- **Retuning:** `retune(score, track, tuning, octave)` runs on one guitar track, with `octave` from −2 to 2.
  - **Pitch:** a note's pitch is its open-string pitch + fret + 12 × octave.
  - **Strings, step 4:** old and new strings are matched from the top string down, so 7 → 6 removes the lowest string and 6 → 7 adds a low string.
  - **New fret, step 1:** the note's mapped string gives `newFret = pitch − newOpen(mapped)`.
  - **Groups:** notes joined by a tie, hammer-on/pull-off or slide (`tieDestination`, `hammerPullDestination`, `slideTarget` before the retune) form a group.
  - **Moving, step 2:** a group with any member out of range (`newFret` outside 0–24, or a removed string) moves as a whole to the cheapest string where every member is playable and free. When no string fits the whole group, each out-of-range member moves on its own. Every link between members left on different strings is removed: `isHammerPullOrigin = false`, `slideOutType = None`, or `isTieDestination = false`.
  - **Unplayable, step 3:** an out-of-range note that no free string can play keeps its original fret. It stays on its mapped string, or, if that string was removed, on the nearest remaining string by pitch.
  - **Counting:** a note counts as moved when its final string isn't its mapped string, and as unplayable under step 3.
  - **What else changes:**
    - the staff's tuning, with `stringTuning.name = ''`;
    - a natural harmonic's `harmonicValue`, which follows its fret, as `setFret` does;
    - chord diagrams of the staff, shifted per string like notes. A diagram with a fret outside 0–24, or a played note on a removed string, gets `showDiagram = false`.
  - **Finishing:** `finishEdit` relinks everything.
  - **Edits:** it is an undoable track edit (`TRACK_OPS`), and it needs no cursor. Retuning to the current tuning at octave 0 is a no-op.
- **Marks:**
  - **Contents:** the moved notes (amber) and unplayable notes (red) of the last retune or of fingering on open.
  - **Lifetime:** they are drawn on the drawn track's tab, as tints the size of the edit cursor. They last until the next edit, undo or redo.
  - **Hidden tab:** with the tab hidden, no tints are drawn and the report still shows.
  - **Colours:** amber `rgba(245, 166, 35, 0.4)` and red `rgba(230, 60, 60, 0.4)`.
- **Report, step 5:**
  - **What:** `EditState.retune` is `{ track, tuning, octave, moved, unplayable }` after a retune, and stays until the next edit, undo or redo. It is null otherwise.
  - **Where:** when either count isn't zero, the track panel shows "{moved} moved to another string, {unplayable} can't be played", with Undo, **Octave up** and **Octave down**.
  - **Octave:** up or down undoes the retune, then retunes again with the octave ±1. Each button is disabled at ±2.
- **Fingering message:** when an opened song has unplayable notes, a SnackBar says "{count} notes can't be played in this tuning. They're marked in red." `SongSummary.unplayableNotes` carries the count from `open`; it is 0 elsewhere.
- **Retune dialog:**
  - **Heading:** "Retune {track}";
  - **Body:** `TuningFields`, starting at the track's tuning, followed by the line "Every note keeps its pitch; frets move.";
  - **Buttons:** Cancel and Retune.
  - **Starting tuning:** `TuningFields` gains `initial`, used when the string count is 6–8 and every note lies within its dropdown range. It shows a preset's name when it equals one, otherwise Custom.

## Review Focus

1. **Retuning a whole real song** (Collateral Damage, E♭ standard, to D and to E standard) keeps the note count. Every note keeps its pitch or is counted unplayable, and the counts match the marks. Test: Task 2 `the private sample keeps every note through a retune`.
2. **Undo after a retune** restores the tuning, frets, strings and techniques exactly, and a retuned song survives the `.gp` round-trip. Test: Task 2 `a retune is undoable and survives the .gp round-trip`.
3. **Retuning 7 → 6 with the cursor on the 7th string** leaves the cursor on a string that exists. Test: Task 3 `a retune to fewer strings keeps the cursor on a real string`.
4. **A pitch-only part with chords and ties** gets distinct strings within each chord, and keeps each tie on one string and fret. Tests: Task 1 `chord notes get distinct strings`, `tied notes share string and fret`: the F4 and its tie destination are both on 5/6.
5. **Octave up twice, then Undo,** reruns from the original song each time, and Undo returns the original tuning. Test: Task 4 `octave reruns retune from the original song`.

---

### Task 1: String choice and automatic fingering

**Files:**
- Create: `engine/src/editing/fingering.ts`, `engine/test/editing/fingering.test.ts`
- Modify: `engine/src/summary.ts`, `engine/src/main.ts`, `engine/src/protocol.ts`, `engine/test/fixtures.ts`, `engine/test/summary.test.ts`

**Interfaces:**
- Produces, in `fingering.ts`:
  - `MAX_FRET = 24`;
  - `positionCost(frets: number[], anchor: number): number`;
  - `isFree(bar: Bar, string: number, beat: Beat, ignore: Set<Note>): boolean`;
  - `anchorBefore(beat: Beat): number`;
  - `export type NoteMark = { bar: number; voice: number; beat: number; string: number; kind: 'moved' | 'unplayable' }`;
  - `fingerUnstrung(score: Score, settings?: alphaTab.Settings): Map<number, NoteMark[]>`, the unplayable marks per track index, empty when nothing was fingered.
- Produces, in the protocol: `SongSummary.unplayableNotes: number`.
  - `describeOpened(score, name, unplayable = 0)` fills it, and `summarize` gives 0.
  - In `main.ts`, the open hook keeps the fingering result in a module variable `openedMarks` for Task 3, and `open` passes its total count to `describeOpened`.
- Fixture `pitchesOnly`:
  - track `"P" \instrument 25 \tuning piano`;
  - bar 1: `G3.4 A3.4 B3.4 C4.4`;
  - bar 2: `E4.4 (E2 B3 E4).4 C5.4 D4.4`;
  - bar 3: an F4 tied across into bar 4, and `C2.4 C7.4`.

- [ ] **Step 1: Write the failing tests** in `fingering.test.ts`. In alphaTab's numbering, string 1 is E2 and string 6 is E4.
  - `positionCost prefers open strings, low frets and a short stretch`: `[0]` → 0; `[5]` with anchor 0 → 5.5; `[1, 7]` with anchor 0 → 8.8 + 20.
  - `a pitch-only guitar part gets standard E strings and frets`: the tuning becomes `[64, 59, 55, 50, 45, 40]`, every note has `string ≥ 1`, and every `realValue` is unchanged.
  - `the lowest position wins`: bar 1 gives G3 on 4/0, A3 on 4/2, B3 on 5/0 and C4 on 5/1.
  - `consecutive notes stay close`: in bar 2, C5 goes on 6/8 and then D4 on 4/7, the anchor being 1 and then 8.
  - `chord notes get distinct strings`: (E2 B3 E4) gives 1/0, 5/0 and 6/0.
  - `tied notes share string and fret`: the F4 and its tie destination are both on 5/6.
  - `notes no string can play are counted`: C2 gives 1/0 and C7 gives 6/32. The result maps track 0 to two `unplayable` marks.
  - `stringed tracks and other instruments are left alone`: `twoGuitarsAndDrums` comes back unchanged, and a piano-program track with notes but no strings isn't fingered.

  In `summary.test.ts`:
  - `a pitch-only guitar part summarises with its fingered tuning`: 6 strings, and `unplayableNotes` 0 from `summarize`.
- [ ] **Step 2: Run them to verify they fail:** `npm --prefix engine test -- fingering summary`. Expected: FAIL, with `fingering.ts` missing.
- [ ] **Step 3: Implement.** A beat's assignment is a backtracking search over each note's candidate strings, as the Global Constraints define it. Call `fingerUnstrung` in `summarize` and in the `fromFile` branch of the `scoreLoaded` hook, before `showNotationAndTab`. It ends with `finishEdit(score, { track, bar: 0, voice: 0, beat: 0, string: 1 }, settings)` for each fingered track.
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(engine): give pitch-only guitar parts strings and frets`

---

### Task 2: Retune in the engine

**Files:**
- Create: `engine/src/editing/retune.ts`, `engine/test/editing/retune.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/src/editing/commands.ts`, `engine/test/fixtures.ts`

**Interfaces:**
- Consumes: Task 1's `positionCost`, `isFree`, `anchorBefore`, `MAX_FRET` and `NoteMark`.
- Produces:
  - in `retune.ts`: `retune(score: Score, track: number, tuning: number[], octave: number, settings?): NoteMark[]`, the moved and unplayable marks. It throws `only guitar tracks can be retuned`, `a tuning needs 1 to 10 strings` and `octave must be -2 to 2`;
  - in the protocol: `EditCommand` gains `{ op: 'retune'; track: number; tuning: number[]; octave: number }`;
  - `TRACK_OPS` includes `'retune'`;
  - `runCommand`'s result gains `marks: NoteMark[]`, which is empty for every other op.
- Fixtures, in D standard `D4 A3 F3 C3 G2 D2`:
  - `dStandardRiff`: `2.6.4 4.5.4 (1.2 3.4).4 0.6.4`;
  - `dStandardLegato`: `1.5{h} 3.5`, and a bar of `1.5{h} 24.5`;
  - `sevenString`: B standard 7-string `0.7.4 5.1.4`.

  These use alphaTex string numbers, 1 being the highest.

- [ ] **Step 1: Write the failing tests** in `retune.test.ts`:
  - **`retuning keeps each pitch and moves the frets`:** `dStandardRiff` to E standard lowers frets by 2: 2→0 and 4→2. Every `realValue` is unchanged.
  - **`a note out of range moves to a free string`:** in `dStandardRiff`'s chord, the B♭3 at fret 1 on the A3 string gives −1 on the new B3 string. It goes to the free G3 string at fret 3, a `moved` mark, and the chord's E♭3 stays on the D3 string at fret 1.
  - **`a note no string can play keeps its fret and is marked`:** the open low D (D2) has no string in E standard. It stays on the low string at fret 0, as an `unplayable` mark.
  - **`a hammer-on moves with its partner`:** `1.5{h} 3.5` to E standard moves both notes to the low E string, at frets 4 and 6, with the hammer-on kept.
  - **`a group that can't stay together loses its link`:** `1.5{h} 24.5` moves the first note alone, to low E fret 4. The second stays at fret 22, and the hammer-on is removed.
  - **`fewer strings map from the top`:** `sevenString` to 6-string E standard keeps the top note on the high E string at fret 5. The low B is `unplayable`, on the new lowest string at fret 0.
  - **`an octave shifts every pitch`:** octave 1 raises every `realValue` by 12, so frets rise by 12 where playable.
  - **`chord diagrams follow the retune`:** a diagram in D standard shifts by −2 per string, and one that goes below 0 is hidden.
  - **`the tuning name follows the new tuning`:** after E standard, `stringTuning.name` is `Guitar Standard Tuning`.
  - **`a retune is undoable and survives the .gp round-trip`:** through `runCommand` with `History`, `edited` is true. The `Gp7Exporter` → `ScoreLoader` round-trip keeps the tuning and frets, and undo restores the original JSON snapshot.
  - **`retuning to the same tuning changes nothing`:** `runCommand` gives `edited: false`.
  - **`the private sample keeps every note through a retune`:** this test reads `DUOSCORE_PRIVATE_SAMPLE` and skips when it is unset. Track 0, from E♭ to D standard and to E standard: the note count is unchanged, and every note keeps its `realValue` unless it has an `unplayable` mark.
- [ ] **Step 2: Run them to verify they fail:** `npm --prefix engine test -- retune`. Expected: FAIL, with `retune.ts` missing.
- [ ] **Step 3: Implement.**
  1. Map every note to its new string and fret.
  2. Collect the groups before changing anything.
  3. Relocate out-of-range groups in time order. Each check of a free string sees the notes already placed. Out-of-range notes not yet placed don't occupy a string.
  4. Apply the tuning, harmonics and chord diagrams, then `finishEdit`.
  5. Wire `retune` into `runCommand`, which returns its marks.
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(engine): retune a guitar track, keeping every pitch`

---

### Task 3: Marks, report and overlay

**Files:**
- Modify:
  - `engine/src/editing/session.ts`, `engine/src/editing/overlay.ts`, `engine/src/main.ts`;
  - `engine/src/protocol.ts`, `engine/index.html`.
- Test: `engine/test/editing/session.test.ts`, `engine/test/editing/hit_test.test.ts`

**Interfaces:**
- Consumes:
  - Task 1's `NoteMark` and `openedMarks`;
  - Task 2's `retune` command and `runCommand(...).marks`.
- Produces:
  - **Protocol:**
    - `RetuneReport = { track: number; tuning: number[]; octave: number; moved: number; unplayable: number }`;
    - `EditState.retune: RetuneReport | null`.
  - **Session:**
    - `EditSession.marks: Map<number, NoteMark[]>`;
    - `open(score, track, name, marks = new Map())`.
    - A retune sets that track's marks and the report.
    - Any other edited command, undo or redo (`restored`) clears both.
    - The retune keeps the cursor's track and runs `clampPosition` on it.
  - **Overlay:**
    - `markRects(renderer, score, track: number, marks: NoteMark[]): { rect: Rect; kind: NoteMark['kind'] }[]` uses `cursorRect`'s geometry;
    - `drawOverlay` gains `marks: NoteMark[]` and draws `.dt-note-moved` or `.dt-note-unplayable`;
    - `main.ts` passes `session.marks.get(session.track) ?? []`.

- [ ] **Step 1: Write the failing tests:**
  - **`session.test.ts`:**
    - `a retune reports its counts until the next edit`: retuning `dStandardRiff` to E gives `retune` `{ track: 0, octave: 0, moved: 1, unplayable: 1 }` and two marks. A `setFret` clears both.
    - `undo clears the retune report and marks`.
    - `a retune to fewer strings keeps the cursor on a real string`: the cursor on string 7 of `sevenString`, retuned to 6 strings, ends on a string ≤ 6.
    - `opening with fingering marks keeps them until the next edit`.
  - **`hit_test.test.ts`:** `mark rects sit on their tab string like the cursor`: a mark at bar 0, beat 1, string 6 has `cursorRect`'s rect for that position.
- [ ] **Step 2: Run them to verify they fail:** `npm --prefix engine test -- session hit_test`. Expected: FAIL, with `retune` missing from the state.
- [ ] **Step 3: Implement,** and add the two mark styles to `engine/index.html`.
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && npm --prefix engine run build`. Expected: all pass, and the build succeeds.
- [ ] **Step 5: Commit** `feat(engine): mark moved and unplayable notes until the next edit`

---

### Task 4: Retune in the cubits

**Files:**
- Modify: `lib/engine/protocol.dart`, `lib/features/editor/editor_cubit.dart`
- Test: `test/unit/engine/protocol_test.dart`, `test/unit/features/editor/editor_cubit_test.dart`

**Interfaces:**
- Consumes:
  - Task 2's `retune` command;
  - Task 3's `EditState.retune`;
  - Task 1's `SongSummary.unplayableNotes`.
- Produces:
  - **Protocol:**
    - `class RetuneTrack extends EditCommand(track, tuning, octave)`, serialised as `op: 'retune'`;
    - `class RetuneReport { track, tuning, octave, moved, unplayable }` with `fromJson`;
    - `EditState.retune: RetuneReport?`;
    - `SongSummary.unplayableNotes` (default 0).
  - **Cubit:**
    - `EditorState.retune: RetuneReport?`;
    - `EditorCubit.retune(int track, List<int> tuning, {int octave = 0})`;
    - `EditorCubit.retuneOctave(int delta)` runs `undo()`, then `retune(report.track, report.tuning, octave: report.octave + delta)`. It does nothing without a report, or when the octave would leave −2…2.

- [ ] **Step 1: Write the failing tests:**
  - **`protocol_test.dart`:** `retune serialises its track, tuning and octave`, and `the edit state reads the retune report`.
  - **`editor_cubit_test.dart`:**
    - `retune sends the command without a cursor and keeps the report`;
    - `octave reruns retune from the original song`: after a report at octave 0, `retuneOctave(1)` calls undo, then retune at octave 1. A second `retuneOctave(1)` gives octave 2, and a third sends nothing;
    - `an edit without a report clears it`.
- [ ] **Step 2: Run them to verify they fail:** `flutter test test/unit/engine/protocol_test.dart test/unit/features/editor/editor_cubit_test.dart`. Expected: FAIL, with `RetuneTrack` missing.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test && flutter analyze`. Expected: all pass, and no issues.
- [ ] **Step 5: Commit** `feat: retune and octave reruns in the editor cubit`

---

### Task 5: Retune dialog, report and fingering message

**Files:**
- Create: `lib/features/editor/retune_dialog.dart`, `test/widget/editor/retune_dialog_test.dart`
- Modify:
  - `lib/features/editor/tuning_fields.dart`, `lib/features/score/track_info_panel.dart`, `lib/features/score/score_page.dart`, `lib/l10n/app_en.arb`;
  - `test/widget/score/track_info_panel_test.dart`, `test/widget/score/score_page_test.dart`, `test/widget/editor/new_song_dialog_test.dart`.

**Interfaces:**
- Consumes: Task 4's `EditorCubit.retune`, `retuneOctave`, `undo` and `EditorState.retune`, and `SongSummary.unplayableNotes`.
- Produces:
  - `TuningFields({required onChanged, List<int>? initial})`;
  - `RetuneDialog({required String trackName, required List<int> tuning})`, which pops the chosen tuning, or null on Cancel;
  - **Track panel:**
    - a **Retune…** button under the tuning;
    - the report card, when `retune` is set for the drawn track and a count isn't zero.
  - **Score page:** a `BlocListener` that shows the fingering SnackBar once per `openId` when `unplayableNotes > 0`.
- l10n:
  - `retune`: "Retune…";
  - `retuneHeading`: "Retune {track}";
  - `retuneHint`: "Every note keeps its pitch; frets move.";
  - `retuneConfirm`: "Retune";
  - `retuneReport`: "{moved, plural, =0{No notes moved} =1{1 note moved to another string} other{{moved} notes moved to another string}}, {unplayable, plural, =0{all can be played} =1{1 can't be played} other{{unplayable} can't be played}}";
  - `octaveUp`: "Octave up";
  - `octaveDown`: "Octave down";
  - `undo`, reused if it exists, else "Undo";
  - `unplayableOnOpen`: "{count, plural, =1{1 note can't be played in this tuning. It's marked in red.} other{{count} notes can't be played in this tuning. They're marked in red.}}".

- [ ] **Step 1: Write the failing tests:**
  - **`retune_dialog_test.dart`:**
    - `the dialog starts at the track's tuning`: Standard D shows the preset "Standard D", and a custom tuning shows Custom with its notes.
    - `Retune pops the chosen tuning and Cancel pops null`.
  - **`new_song_dialog_test.dart`:** `new song still starts at 6-string standard E`.
  - **`track_info_panel_test.dart`:**
    - `Retune opens the dialog and sends the chosen tuning`;
    - `the report shows the counts with Undo and the octave buttons`;
    - `Octave up is disabled at +2`;
    - `no report shows when both counts are zero`.
  - **`score_page_test.dart`:** `an opened song with unplayable notes says so once`.
- [ ] **Step 2: Run them to verify they fail:** `flutter test test/widget`. Expected: FAIL, with `retune_dialog.dart` missing.
- [ ] **Step 3: Implement,** then run `flutter gen-l10n`.
- [ ] **Step 4: Run the checks:**
  ```
  npm --prefix engine run build && flutter test && flutter analyze \
    && flutter build ios --simulator \
    && xcrun simctl install booted build/ios/iphonesimulator/Runner.app \
    && xcrun simctl launch booted dev.edbrsk.duoscore
  ```
  Expected: all pass, no issues, and the app launches.
- [ ] **Step 5: Commit** `feat: Retune dialog and report in the track panel`

---

## Owner checks on the simulator

1. **Retune a Collateral Damage guitar track from E♭ to E standard:**
   - the tab frets rise by 1 and it sounds the same;
   - the report appears only if some notes moved, or can't be played, with amber or red tints on them.
2. **Retune it to D standard:** frets drop by 1. If anything can't be played, Octave up reruns the retune, and Undo brings back E♭.
3. **Add a 7-string track** (Plan 5c), write a note on the low B, then retune the track to 6-string E standard. That note is red, the report counts it, and the cursor stays on a real string.
4. **Import a MusicXML guitar part without tab:**
   - it opens with tab in standard E, and plays the same;
   - any notes out of range give the message and show red.
5. **Save, and open the copy in Guitar Pro 8:** the new tuning and frets are there.
