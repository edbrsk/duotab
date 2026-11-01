# DuoScore Plan 11: Chords Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** With the cursor on a beat, the owner builds a chord symbol by tapping. DuoScore offers the playable positions for the track's own tuning, and writes the chosen one's notes and name on the beat in one step.

**Architecture:** The engine owns chords:
- `chord_names.ts`: the tones, naming and name reading;
- `chord_positions.ts`: the position finder;
- `chords.ts`: the `setChord` edit;
- a `chordPositions` request, and the cursor beat's chord and frets in `EditState`.

Flutter adds a Frets | Chords switch to the track panel and a tap-built `ChordPicker` that draws positions as diagrams and sends `SetChord`.

**Tech Stack:** TypeScript and vitest in `engine/` (alphaTab 1.6.1); Flutter 3.47.8 with `flutter_bloc` and `mocktail`.

**Spec:** `docs/superpowers/specs/2026-11-01-duoscore-chords-design.md` (extends `docs/superpowers/specs/2026-10-29-duoscore-design.md`)

## Global Constraints

- **Strings are numbered as alphaTab does:** string 1 is the lowest string. Every `frets` list in this plan is **low string first**, with **−1 for a string not played**. alphaTab's `Chord.strings` is the reverse: highest string first.
- **Pitch classes:** `root` and `bass` are 0–11 with C = 0. Names spell roots as `C C♯ D E♭ E F F♯ G A♭ A B♭ B` and use `♭`/`♯` in symbols (`m7♭5`, `7♭9`). Reading accepts `b`/`#` too.
- **Highest fret** is 24 (`MAX_FRET` in `operations.ts`). **Open strings** are the staff's `tuning` reversed, plus `staff.capo`.
- **Chord tones, names, positions and the barre rule** are exactly the spec's tables and rules (Chord tones, Names, Positions).
- **The engine bundle:** after any engine change, run `npm --prefix engine run build` before building the app.
- **Comments:** only a non-obvious why, one line where possible. `dart format` only on the files a task touches; no prettier in `engine/`.
- **Checks:**
  - `npm --prefix engine test` and `cd engine && npx tsc --noEmit` stay green;
  - `flutter test` and `flutter analyze` (`No issues found!`) stay green.

## Review Focus

1. **Tapping root, type and additions quickly:** replies can arrive out of order, and the strip must show the positions of the last symbol built (Task 5: `a late reply never replaces a newer chord's positions`).
2. **A capo:** positions follow the capo-shifted open strings, as the fret pad's frets do (Task 2: `a capo shifts the open strings`).
3. **7- and 8-string tracks:** positions use every string, each `frets` list is as long as the string count, and the finder stays quick (Task 2: `an 8-string track finds every chord quickly`).
4. **Another voice:** writing a chord in voice 2 leaves voice 1 untouched (Task 3: `a chord in another voice leaves the first voice alone`).
5. **Undo and redo:** they restore the beat's previous notes and remove, or bring back, the name (Task 3: `undo removes the chord and redo brings it back`).

---

### Task 1: Chord tones, names and reading names back

**Files:**
- Create: `engine/src/editing/chord_names.ts`
- Modify: `engine/src/protocol.ts` (types only)
- Test: `engine/test/editing/chord_names.test.ts`

**Interfaces:**
- Produces, in `protocol.ts`:
  - `type ChordType = 'maj'|'m'|'7'|'maj7'|'m7'|'m7b5'|'dim7'|'aug'|'sus2'|'sus4'|'6'|'5'`
  - `type ChordAddition = 'b9'|'9'|'#9'|'11'|'#11'|'b13'|'13'`
  - `type ChordSpec = { root: number; type: ChordType; additions: ChordAddition[]; bass: number | null }`
- Produces, in `chord_names.ts`:
  - `chordTones(spec): { required: number[]; optional: number[] }`: pitch classes. `optional` is the spec's droppable "5th", or empty for a 5 chord. The bass isn't included.
  - `chordName(spec): string`
  - `parseChordName(name: string): ChordSpec | null`
  - `withAddition(additions, added): ChordAddition[]`: adds `added` and drops the clash group's other member. The groups are `{b9, 9, #9}`, `{11, #11}` and `{b13, 13}`.

- [ ] **Step 1: Write the failing tests:**
  - `names follow the lead-sheet table`: assert every row of the spec's Names table, with root C. Also `{root: 0, type: 'maj7', additions: [], bass: 4}` → `Cmaj7/E` and `{root: 11, type: '7', additions: ['b9'], bass: null}` → `B7♭9`.
  - `tones follow the tone table`:
    - maj7 → required `[0,4,11]`, optional `[7]`;
    - m7♭5 → optional `[6]`;
    - 5 → required `[0,7]`, optional `[]`;
    - 7 + 13 → required `[0,4,10,9]` (order-insensitive) with 7 optional.
  - `every name reads back as the chord it names`: every root × type × each choice from the three clash groups (none or one member each) × bass (null or 0–11, sampled every 5th) round-trips `parseChordName(chordName(spec))`, with additions compared as sets.
  - `ASCII spellings read too`: `Bb7b9` → root 10, `7`, `[b9]`; `C#m7` → root 1, `m7`.
  - `names DuoScore can't build read as null`: `N.C.`, `A7sus4`, `C7#5`, empty string.
  - `a clashing addition replaces its partner`: `withAddition(['b9'], '9')` → `['9']`.
- [ ] **Step 2: Run them to verify they fail**
  Run: `cd engine && npx vitest run test/editing/chord_names.test.ts`
  Expected: fails on the missing module.
- [ ] **Step 3: Implement**:
  - **Names:** `chordName` builds root + base + extensions + bracket group + `/bass`.
    - **Bases:** maj "", m "m", 7 "7", maj7 "maj7", m7 "m7", m7b5 "m7♭5", dim7 "dim7", aug "aug", sus2 "sus2", sus4 "sus4", 6 "6", 5 "5".
    - **Stacking:** for 7, maj7 and m7 only, a 9 makes the 7 into 9/maj9/m9, and with the 9, a 13 makes it 13, or an 11 without a 13 makes it 11. An 11 beside a 13 goes in the brackets.
    - **6 + 9** is `6/9`.
    - **maj and m:** naturals read `add9`/`add11`/`add13`. A maj with one natural and nothing else is unbracketed (`Cadd9`); m is always bracketed (`Cm(add9)`).
    - **The bracket group:** everything left over, ordered 9s, 11s, 13s. A lone alteration with nothing else in the group goes unbracketed (`C7♭9`).
  - **Reading:** `parseChordName` normalises `#`→`♯` and `b` before a digit or after the root letter→`♭`, splits the root, suffix and `/bass`, and finds the suffix in a map built once from every type × addition choice.
- [ ] **Step 4: Run them to verify they pass**
  Run: `cd engine && npx vitest run test/editing/chord_names.test.ts && npx tsc --noEmit`
  Expected: all pass, no type errors.
- [ ] **Step 5: Commit**
  `git add engine/src/editing/chord_names.ts engine/src/protocol.ts engine/test/editing/chord_names.test.ts && git commit -m "feat(engine): chord tones, lead-sheet names, and names read back"`

### Task 2: The position finder

**Files:**
- Create: `engine/src/editing/chord_positions.ts`
- Modify: `engine/src/protocol.ts` (types only)
- Test: `engine/test/editing/chord_positions.test.ts`

**Interfaces:**
- Consumes: `chordTones` and `ChordSpec` from Task 1.
- Produces:
  - `type ChordPosition = { frets: number[]; open: boolean; lowestFret: number }` in `protocol.ts`. `lowestFret` is 0 when nothing is fretted. `open` is true when the shape has an open string and its highest fret is ≤ 4, which the picker labels "Open"; otherwise it shows "Fret {lowestFret}".
  - `chordPositions(spec, openStrings: number[], maxFret = 24): ChordPosition[]`, where `openStrings` are MIDI pitches with the low string first.
  - `openStringsOf(staff): number[]`: the staff's tuning reversed, plus `staff.capo`.

- [ ] **Step 1: Write the failing tests** (low string first, E standard = `[40,45,50,55,59,64]`, drop B = `[35,42,47,52,56,61]`):
  - `Cmaj7 in E standard`: the frets include `[-1,3,2,0,0,0]`, `[-1,3,5,4,5,3]` and `[8,-1,9,9,8,-1]`. The first has `open: true`. The list is sorted by `lowestFret`, open shapes first at the same `lowestFret`, then by more sounding strings.
  - `B7♭9 in E standard` includes `[-1,2,1,2,1,2]` and `[7,-1,7,8,7,8]`.
  - `Cmaj7 in drop B` includes `[1,1,0,0,-1,-1]`.
  - `no position needs five fingers`: Cmaj7 in E standard excludes `[-1,3,2,4,5,3]`.
  - `every position keeps the rules`: for every root × type × one addition (or none) on E standard, drop B and B-standard 7-string `[35,40,45,50,55,59,64]`, every position:
    - spans ≤ 3 frets;
    - has frets ≤ 24;
    - needs ≤ 4 fingers under the spec's barre rule;
    - sounds only chord tones (plus the bass);
    - has the root or bass as its lowest sounding note;
    - holds every required tone.
  - `a chord no hand can hold has no positions`: 7 + ♭9 + ♯11 + ♭13 in E standard → `[]`.
  - `a capo shifts the open strings`: `openStringsOf` on a staff with `capo = 2` in E standard → `[42,47,52,57,61,66]`.
  - `an 8-string track finds every chord quickly`: every root × type with no additions on `[30,35,40,45,50,55,59,64]` finishes in under 3 s, and every `frets` has length 8.
- [ ] **Step 2: Run them to verify they fail**
  Run: `cd engine && npx vitest run test/editing/chord_positions.test.ts`
  Expected: fails on the missing module.
- [ ] **Step 3: Implement**:
  - **Search:** depth-first over the strings, low to high. Each string can be −1, open (if its pitch class is a chord tone or the bass), or a fret 1–`maxFret` sounding a chord tone. Prune as soon as the fretted span exceeds 3.
  - **Keep a shape when** the lowest sounding pitch class is the bass (or the root), it holds every required tone, it has at least two sounding strings, and the finger count is ≤ 4.
  - **Finger count:** the fretted notes, minus the most notes at the lowest fret that one unbroken run of strings can cover, plus 1 if that run covers two or more. A run contains no −1 or 0, and its strings sound at that fret or higher.
  - **Order** as in the first test.
- [ ] **Step 4: Run them to verify they pass**
  Run: `cd engine && npx vitest run test/editing/chord_positions.test.ts && npx tsc --noEmit`
  Expected: all pass.
- [ ] **Step 5: Commit**
  `git add engine/src/editing/chord_positions.ts engine/src/protocol.ts engine/test/editing/chord_positions.test.ts && git commit -m "feat(engine): playable chord positions for a track's own tuning"`

### Task 3: Writing a chord, and what the engine reports about it

**Files:**
- Create: `engine/src/editing/chords.ts`
- Modify:
  - `engine/src/editing/commands.ts` (dispatch `setChord`; the `shape` key)
  - `engine/src/editing/operations.ts` (`deleteNote`, `setRest`)
  - `engine/src/editing/bar_structure.ts` (export `chordIn`)
  - `engine/src/editing/session.ts` (`state`)
  - `engine/src/protocol.ts`
  - `engine/src/main.ts` (the `chordPositions` request)
- Test: `engine/test/editing/chords.test.ts`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces:
  - **Command:** `EditCommand` gains `{ op: 'setChord'; chord: ChordSpec; frets: number[] }`.
  - **Function:** `setChord(score, at, spec, frets, settings): EditPosition` in `chords.ts`. It returns `at`, so the cursor stays on the beat.
  - **Request:** `chordPositions` with payload `{ track: number; chord: ChordSpec }` replies `{ name: string; positions: ChordPosition[] }`.
  - **`EditState.beat` gains:**
    - `chord: { name: string; spec: ChordSpec | null } | null` (the spec is `parseChordName(name)`);
    - `frets: number[]`, the beat's notes, low string first, −1 where none.

- [ ] **Step 1: Write the failing tests** on the `fourQuarters` fixture (E standard), cursor `at(0, 1)`:
  - `writing Cmaj7 puts its notes and name on the beat`:
    - `setChord(s, at(0,1), cmaj7, [-1,3,2,0,0,0])`;
    - the beat's `[string, fret]` pairs are `[[2,3],[3,2],[4,0],[5,0],[6,0]]`;
    - `beat.chord!.name` is `Cmaj7` and `beat.chord!.strings` is `[0,0,0,2,3,-1]`;
    - `beat.chord!.showDiagram` is false;
    - the returned position equals `at(0,1)`.
  - `a chord replaces the beat's notes and touches nothing else`: put frets on beats 0 and 1, write a chord on beat 1. Beat 0 is unchanged, and beat 1 holds only the chord's notes.
  - `a chord in another voice leaves the first voice alone`: in voice 1, voice 0's beats are unchanged.
  - `a frets list that isn't one of the chord's positions is refused`: `[-1,3,3,0,0,0]` throws.
  - `undo removes the chord and redo brings it back`: through `runCommand`, which pushes one step. Undo restores the original beat with `chordId` null; redo restores the notes and the name.
  - `rewriting with another position counts as an edit`: `runCommand` with `[-1,3,5,4,5,3]` after the open shape gives `edited: true`. Rewriting with the same position and a different symbol of the same notes, Cmaj7 → Em/C, is also an edit (the `shape` key includes beat chord ids and chord names).
  - `editing one of its notes keeps the name`: `setFret` on the chord beat's string 2 → `chordId` unchanged.
  - `deleting a chord's last note drops its name`: `setRest` on the chord beat, then `chordId` is null. So does `deleteNote` on each note in turn.
  - `the cursor beat reports its chord and frets`: `session.state(...).beat` gives `chord: {name: 'Cmaj7', spec: cmaj7}` and `frets: [-1,3,2,0,0,0]`. A beat with the chord name `N.C.` reports `spec: null`.
  - `Guitar Pro keeps the chord`: export with `Gp7Exporter`, re-import, and the beat still has chord `Cmaj7` and the same notes.
- [ ] **Step 2: Run them to verify they fail**
  Run: `cd engine && npx vitest run test/editing/chords.test.ts`
  Expected: fails on the missing module.
- [ ] **Step 3: Implement**:
  - **`setChord`:**
    - check that `frets` equals one of `chordPositions(spec, openStringsOf(staff))`, or throw `not a position of this chord`;
    - remove the beat's notes and add one per played string, with ids from `idSource`;
    - build a `Chord` with `name = chordName(spec)`, `strings` high to low, `firstFret = open ? 1 : lowestFret` and `showDiagram = false`;
    - set `beat.chordId = chordIn(staff, chord, chord.name)`, then `beat.isEmpty = false` and `finishEdit`.
  - **Clearing the name:** `deleteNote` and `setRest` set `beat.chordId = null` when the beat is left with no notes.
  - **`main.ts`:** the `chordPositions` case reads the track's first staff.
- [ ] **Step 4: Run them to verify they pass**
  Run: `npm --prefix engine test && cd engine && npx tsc --noEmit`
  Expected: all pass, including the earlier 328.
- [ ] **Step 5: Commit**
  `git add engine/src engine/test && git commit -m "feat(engine): write a chord on a beat, report it, and offer its positions"`

### Task 4: The app learns about chords

**Files:**
- Modify:
  - `lib/engine/protocol.dart`
  - `lib/engine/engine_bridge.dart`
  - `lib/features/editor/editor_cubit.dart`
  - `lib/features/settings/settings_cubit.dart`
- Test:
  - `test/unit/engine/protocol_test.dart` (or the file that already tests `EditState.fromJson`)
  - `test/unit/features/editor/editor_cubit_test.dart`
  - `test/unit/features/settings/settings_cubit_test.dart`

**Interfaces:**
- Consumes: Task 3's JSON.
- Produces:
  - **Protocol types:**
    - `class ChordSpec { final int root; final String type; final List<String> additions; final int? bass; }` with `toJson`/`fromJson` and value equality (additions as a set);
    - `class ChordPosition { final List<int> frets; final bool open; final int lowestFret; }`;
    - `class ChordPositions { final String name; final List<ChordPosition> positions; }`;
    - `class SetChord extends EditCommand { const SetChord(this.chord, this.frets); }`.
  - **`EditState`:** `String? chordName`, `ChordSpec? chordSpec`, `List<int> beatFrets` (empty without a cursor).
  - **Bridge:** `EngineBridge.chordPositions(int track, ChordSpec chord) → Future<ChordPositions>`.
  - **`EditorState`:** `chordName`, `chordSpec` and `beatFrets`, plus `EditorCubit.chordPositions(ChordSpec chord) → Future<ChordPositions?>`. It returns null without a cursor or on an engine error, and uses `position.track`.
  - **Settings:** `AppSettings.chordsShown` (default false, JSON key `chordsShown`) and `SettingsCubit.setChordsShown({required bool shown})`.

- [ ] **Step 1: Write the failing tests:**
  - `EditState reads the beat's chord`: JSON with `beat.chord: {name: 'Cmaj7', spec: {...}}` and `frets: [-1,3,2,0,0,0]` parses into those fields. With `chord: null` it gives null name and spec.
  - `SetChord sends its chord and frets`: `toJson()` equals `{'op': 'setChord', 'chord': {...}, 'frets': [...]}`.
  - `the editor carries the beat's chord`: a mocked edit reply with a chord ends up in `EditorState`.
  - `chord positions need a cursor`: without a position, `chordPositions` returns null and the engine isn't called.
  - `the chords switch is remembered`: `setChordsShown(shown: true)` persists, and a new cubit reads `chordsShown: true`.
- [ ] **Step 2: Run them to verify they fail**
  Run: `flutter test test/unit/engine test/unit/features/editor/editor_cubit_test.dart test/unit/features/settings`
  Expected: compile errors, because the types don't exist yet.
- [ ] **Step 3: Implement** as the Interfaces block says.
- [ ] **Step 4: Run them to verify they pass**
  Run: `flutter test && flutter analyze`
  Expected: all pass, `No issues found!`.
- [ ] **Step 5: Commit**
  `git add lib/engine lib/features/editor/editor_cubit.dart lib/features/settings test/unit && git commit -m "feat: the app reads chords from the engine and asks for their positions"`

### Task 5: The chord picker

**Files:**
- Create:
  - `lib/features/editor/chord_picker.dart`
  - `lib/features/editor/chord_diagram.dart`
- Modify:
  - `lib/features/score/track_info_panel.dart`
  - `lib/l10n/app_en.arb` (then `flutter gen-l10n`)
- Test:
  - `test/widget/editor/chord_picker_test.dart`
  - `test/widget/score/track_info_panel_test.dart`

**Interfaces:**
- Consumes: Task 4.
- Produces:
  - **`ChordPicker` (`StatelessWidget` wrapper over a `State`):**
    - **Groups:** **ROOT** (12 keys, four per row), **TYPE** (12 single-choice keys), **ADD OR ALTER** (♭9 9 ♯9 11 ♯11 ♭13 13 /bass, using `withAddition`'s clash rule mirrored in Dart). Turning on **/bass** shows a **BASS** row of 12 roots.
    - **Readout:** the name, and the tuning label with "{n} strings" under it.
    - **POSITIONS:** a horizontal list of `ChordDiagram`s, each labelled `Open` or `Fret {n}`.
  - **`ChordDiagram({required List<int> frets, required int firstFret})`:** a `CustomPainter`. It draws one vertical line per string, low string on the left, and 5 frets, with a thick nut when `firstFret == 1`. Played frets are dots, open strings ○ and unplayed strings ×.
  - **Strings:**
    - `frets`: "Frets"; `chords`: "Chords";
    - `chordRoot`: "Root"; `chordType`: "Type"; `chordAddOrAlter`: "Add or alter"; `chordBass`: "Bass";
    - `chordPositionsHeading`: "Positions"; `noChordPosition`: "No playable position in this tuning";
    - `positionOpen`: "Open"; `positionFret`: "Fret {fret}".

- [ ] **Step 1: Write the failing tests** with a mocked `EditorCubit`, and `chordPositions` stubbed to return Cmaj7's three positions from Task 2:
  - **`building Cmaj7 shows its positions`:**
    - tap C, then maj7;
    - `chordPositions(ChordSpec(root: 0, type: 'maj7', additions: [], bass: null))` is called;
    - the readout shows `Cmaj7`;
    - three `ChordDiagram`s appear, labelled `Open`, `Fret 3` and `Fret 8`.
  - **`tapping a position writes it`:** tap the `Fret 3` diagram, and `editor.command(SetChord(cmaj7, [-1,3,5,4,5,3]))` is called once.
  - **`the cursor's chord shows as built`:** with an `EditorState` holding `chordSpec` Cmaj7 and `beatFrets: [-1,3,5,4,5,3]`, C and maj7 show selected, and the `Fret 3` diagram is highlighted (`Key('position-selected')`).
  - **`another file's chord name shows as text`:** with `chordName: 'N.C.'` and `chordSpec: null`, the readout shows `N.C.`, no root is selected, and no positions are requested.
  - **`a late reply never replaces a newer chord's positions`:**
    - make the first `chordPositions` call complete after the second;
    - tap C, then maj7, then m7 quickly;
    - after both complete, the readout and the diagrams are Cm7's.
  - **`a chord with no position says so`:** a reply with empty positions shows `No playable position in this tuning`.
  - **`clashing additions replace each other`:** tap ♭9 then 9, and only 9 is selected.
  - **`the picker is off without a cursor`:** with no position, taps do nothing (`IgnorePointer`, as `FretPad`).
  - **`the panel switches between frets and chords`** (in `track_info_panel_test.dart`):
    - tapping **Chords** calls `settings.setChordsShown(shown: true)`;
    - with `chordsShown` true the panel shows `ChordPicker` and no `FretPad`;
    - with false it shows `FretPad` only;
    - the switch is absent with `editable: false`.
- [ ] **Step 2: Run them to verify they fail**
  Run: `flutter test test/widget/editor/chord_picker_test.dart test/widget/score/track_info_panel_test.dart`
  Expected: compile errors, because `ChordPicker` doesn't exist.
- [ ] **Step 3: Implement**:
  - **Stale replies:** keep a request counter, and drop a reply whose number isn't the latest.
  - **Following the cursor:** the picker reloads its root, type, additions and bass from `EditorState` when the cursor's position or `chordSpec` changes (`BlocListener`).
  - **The panel:** in `TrackInfoPanel`, `heading(l10n.fret), FretPad()` becomes a `SegmentedButton<bool>` (Frets | Chords) followed by `ChordPicker` or `FretPad`.
- [ ] **Step 4: Run them to verify they pass**
  Run: `flutter test && flutter analyze`
  Expected: all pass, `No issues found!`.
- [ ] **Step 5: Build and install:**
  - Run: `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch --terminate-running-process booted dev.edbrsk.duoscore`
  - Expected: `✓ Built`, and the app launches.
- [ ] **Step 6: Update the main design.** In `docs/superpowers/specs/2026-10-29-duoscore-design.md`, under Editor's **Entering notes**, add: "or switch the pad to **Chords** and build a chord symbol to write a whole chord on the beat (see `2026-11-01-duoscore-chords-design.md`)."
- [ ] **Step 7: Commit**
  `git add lib/features/editor/chord_picker.dart lib/features/editor/chord_diagram.dart lib/features/score/track_info_panel.dart lib/l10n test/widget docs/superpowers/specs/2026-10-29-duoscore-design.md && git commit -m "feat(editor): build a chord by tapping and write one of its positions"`
