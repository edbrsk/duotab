# DuoScore Plan 4: Techniques Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the rest of Guitar Pro's note and beat notation to the palette: tuplets, ties and grace notes, accidentals, dynamics, guitar techniques and articulations. Each is drawn in Bravura, heard where MIDI can play it, and saved in the `.gp` copy.

**Architecture:**
- **Engine.** A catalogue of techniques in `engine/src/editing/techniques.ts` names each technique and says whether it belongs to a note or a beat, how to read it and how to set it on alphaTab's model. A new `toggle` command sets or clears one on the cursor's note or beat, and `score.finish` links what alphaTab links itself: hammer-on and slide targets, tie origins, tuplet and grace groups.
- **Edit state.** The reply carries the techniques active at the cursor, so the palette can show them, and whether the cursor string has a note.
- **Dart.** The palette gains five groups, drawn with SMuFL glyphs or the standard notation abbreviations (H, P, P.M., let ring, N.H., A.H., T).

**Tech Stack:** as Plan 3. alphaTab 1.6.1 model fields used:
- `Note`: `isHammerPullOrigin`, `slideOutType`, `bendType`, `bendPoints`, `vibrato`, `isPalmMute`, `isLetRing`, `isDead`, `isGhost`, `harmonicType`, `harmonicValue`, `isTieDestination`, `accentuated`, `isStaccato`, `accidentalMode`.
- `Beat`: `tupletNumerator`, `tupletDenominator`, `graceType`, `dynamics`, `crescendo`, `pickStroke`, `tremoloSpeed`, `tap`, `fermata`.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md` (Editor › Palette groups; Anti-goals: real notation symbols, never drop content)

**Branch:** `plan-4-techniques`, from `main`.

## Roadmap

Plan 3's roadmap had all the remaining tools in one Plan 4. They are split so each plan stays reviewable:

| Plan | Delivers |
|---|---|
| 4 Techniques (this) | tuplets, ties, grace notes, accidentals, dynamics, crescendo/diminuendo, guitar techniques, articulations |
| 5 Bars and tracks | clef, time signature per bar, key signature, repeats, alternate endings, segno/coda, tempo marking; insert, delete, copy and paste bars; adding, removing, reordering and renaming guitar tracks |
| 6 Retune and export | retuning, automatic fingering, `.gp` and PDF export, share sheet |
| Later | sound-bank comparison; drums |

Tones are already written into saved songs: `Mixer.apply` sets `playbackInfo.program` on the score, and `Gp7Exporter` writes it.

## Global Constraints

Plans 1–3's Global Constraints all apply. In addition:

- **Note or beat.** A note technique applies to the note on the cursor's string. If that string has no note it does nothing, makes no undo step and no "(DuoScore)" copy. A beat technique applies to the cursor's beat.
- **Toggles.** Tapping a technique that is on turns it off. In each exclusive group, choosing one replaces the others:
  - accent, marcato and tenuto (`accentuated`);
  - natural and artificial harmonic;
  - pick stroke up and down;
  - the five accidentals;
  - the tuplets.
- **The values the palette sets:**
  - **Bend:** full (`BendType.Bend`, points `(0, 0)`, `(15, 4)`, `(60, 4)`, in quarter tones).
  - **Slide:** shift slide (`SlideOutType.Shift`).
  - **Vibrato:** `Slight`.
  - **Tremolo picking:** sixteenths.
  - **Artificial harmonic:** `harmonicValue` 12.
  - **Fermata:** `Medium`.
  - **Grace note:** a `BeforeBeat` eighth.
  - **Tuplets:** 3:2, 5:4 and 6:4.
- **Dynamics** run forward like a written dynamic. Setting one on a beat changes that beat and the following beats of the same voice that had the old value, up to the next change.
- **Hammer-on and pull-off** are one alphaTab flag; whether the notation reads H or P depends on the frets. The palette has one `H/P` chip.
- **Symbols** are SMuFL glyphs in Bravura where one exists; otherwise the standard notation text that Guitar Pro prints.

## Review Focus

1. **A linking technique with nothing to link to**, such as a hammer-on, slide or tie on the last note of the song, or a tie with no earlier note on that string, must not crash or corrupt the song. Test: Task 1 `linking techniques at the end of the song stay harmless`.
2. **A note technique on a string with no note** must be a no-op: no undo step, no copy. Test: Task 2 `a note technique on an empty string is not an edit`.
3. **Exclusive groups** must replace, not stack. Test: Task 1 `an exclusive technique replaces the others in its group`.
4. **Every technique must survive the `.gp` export** and come back on re-import, or the copy drops content. Test: Task 1 `every technique survives the .gp round-trip`.
5. **Tuplets and grace notes change bar lengths**, and the bar check must stay right about them. Test: Task 1 `a triplet makes the bar check count three-in-two`, `a grace note does not change the bar check`.

---

### Task 1: The technique catalogue

**Files:**
- Create: `engine/src/editing/techniques.ts`, `engine/test/editing/techniques.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/test/fixtures.ts`

**Interfaces:**
- Produces (protocol):
  - `type TechniqueId = 'hammerPull' | 'slide' | 'bend' | 'vibrato' | 'palmMute' | 'letRing' | 'deadNote' | 'ghostNote' | 'naturalHarmonic' | 'artificialHarmonic' | 'tie' | 'accent' | 'marcato' | 'tenuto' | 'staccato' | 'doubleFlat' | 'flat' | 'natural' | 'sharp' | 'doubleSharp' | 'tapping' | 'pickUp' | 'pickDown' | 'tremolo' | 'fermata' | 'crescendo' | 'diminuendo'`.
  - `type Dynamic = 'ppp' | 'pp' | 'p' | 'mp' | 'mf' | 'f' | 'ff' | 'fff'`.
- Produces (engine), in `techniques.ts`. Each function changes `score` in place, calls `score.finish(settings)` and returns the cursor position:
  - `toggleTechnique(score, at, id: TechniqueId)`;
  - `setDynamic(score, at, dynamic: Dynamic)`;
  - `setTuplet(score, at, tuplet: 1 | 3 | 5 | 6)`, where 1 means none;
  - `addGrace(score, at)`, which moves the cursor to the new grace beat.

  It also exports these readers:
  - `activeTechniques(score, at): TechniqueId[]`;
  - `dynamicAt(score, at): Dynamic | null` (null outside the eight values);
  - `tupletAt(score, at): 1 | 3 | 5 | 6`.

- [ ] **Step 1: Add the fixture** `lineOfEighths` to `fixtures.ts`: a 6-string track with `5.3.8 7.3.8 5.3.8 7.3.8 5.3.4 5.3.4 | 0.6.4 0.6.4 0.6.4 0.6.4`.

- [ ] **Step 2: Write the failing tests** in `techniques.test.ts` (`at(bar, beat, string)` as in `operations.test.ts`; string 4 holds the bar-1 notes):
  - `each note technique toggles on and off`: for every note `TechniqueId`, `toggleTechnique` on `at(0, 0, 4)` makes `activeTechniques` include it, and toggling again removes it.
  - `each beat technique toggles on and off`: the same for `tapping`, `pickUp`, `pickDown`, `tremolo`, `fermata`, `crescendo` and `diminuendo`.
  - `a hammer-on links to the next note on the string`: `hammerPull` on `at(0, 0, 4)` → the note's `hammerPullDestination` is beat 1's note.
  - `a tie takes the fret of the note it ties from`: `tie` on `at(0, 5, 4)` → `tieOrigin` is beat 4's note and the fret is 5.
  - `an exclusive technique replaces the others in its group`: `accent` then `marcato` → only `marcato` is active. `pickUp` then `pickDown` → only `pickDown`. `sharp` then `flat` → only `flat`.
  - `a note technique on an empty string does nothing`: `palmMute` on `at(0, 0, 1)` → the song's JSON is unchanged.
  - `linking techniques at the end of the song stay harmless`: `hammerPull`, `slide` and `tie` on `at(1, 3, 1)` (the last note) do not throw, and `score.finish` succeeds again afterwards.
  - `dynamics run forward to the next change`: `setDynamic(at(0, 2), 'pp')` → beats 2–5 of bar 0 and all of bar 1 read `pp`, while beats 0–1 keep `f`. Then `setDynamic(at(1, 0), 'ff')` → bar 1 reads `ff`, and bar 0's beats 2–5 stay `pp`.
  - `a triplet makes the bar check count three-in-two`: `setTuplet` 3 on beats 0–2 → `checkBars` reports bar 0 short by 480. `setTuplet(…, 1)` clears it.
  - `a grace note does not change the bar check`: `addGrace(at(0, 4, 4))` → a `BeforeBeat` beat sits before beat 4 with a note on string 4, the cursor is on it, and `checkBars` is unchanged.
  - `every technique survives the .gp round-trip`: one note or beat for each technique (spread over both bars), plus a dynamic, a triplet and a grace note. `Gp7Exporter` → `ScoreLoader.loadScoreFromBytes` → `activeTechniques`, `dynamicAt` and `tupletAt` read the same at each position.

- [ ] **Step 3: Run them to verify they fail**

Run: `npm --prefix engine test`
Expected: FAIL: `../../src/editing/techniques` not found.

- [ ] **Step 4: Implement `techniques.ts`.**
  - **The catalogue** is a record keyed by `TechniqueId`. Each entry has `level: 'note' | 'beat'`, `get(target): boolean`, `set(target, on): void` and an optional `group`. The values are the ones in Global Constraints.
  - **Exclusive groups:** turning one on turns off the rest of its `group`.
  - **Ties** copy the origin's fret, using the previous beat in the voice that has a note on the same string.
  - **`setDynamic`** walks forward with `beat.nextBeat` while the beat's voice index is the cursor's and its dynamics equal the old value.
  - **`setTuplet`** sets the numerator and denominator (3:2, 5:4, 6:4; 1 clears both).
  - **`addGrace`** inserts a `Beat` with `graceType = BeforeBeat`, an eighth, and one note on the cursor string at the cursor note's fret (0 if there is none). New objects take their ids from `idSource`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`
Expected: all pass; no type errors.

- [ ] **Step 6: Commit**

```bash
git add engine
git commit -m "feat(engine): technique catalogue for notes and beats"
```

---

### Task 2: Techniques over the bridge

**Files:**
- Modify: `engine/src/protocol.ts`, `engine/src/editing/commands.ts`, `engine/src/editing/session.ts`, `engine/src/editing/operations.ts`, `lib/engine/protocol.dart`
- Test: `engine/test/editing/commands.test.ts`, `engine/test/editing/session.test.ts`, `engine/test/editing/operations.test.ts`, `test/unit/engine/engine_bridge_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces (protocol): `EditCommand` gains:
  - `{ op: 'toggle'; technique: TechniqueId }`;
  - `{ op: 'setDynamic'; dynamic: Dynamic }`;
  - `{ op: 'setTuplet'; tuplet: 1 | 3 | 5 | 6 }`;
  - `{ op: 'addGrace' }`.

  `EditState.beat` gains `techniques: TechniqueId[]`, `dynamic: Dynamic | null`, `tuplet: number` and `hasNote: boolean` (the cursor string has a note).
- Produces (Dart): `EditCommand` subclasses `Toggle(String technique)`, `SetDynamic(String dynamic)`, `SetTuplet(int tuplet)`, `AddGrace()`, plus the matching `EditState` fields (`techniques`, `dynamic`, `tuplet`, `hasNote`).

- [ ] **Step 1: Write the failing tests.**
  - `commands.test.ts`: `a note technique on an empty string is not an edit` (no undo step); `a technique toggle is an edit and can be undone`.
  - `session.test.ts`: `the state lists the techniques at the cursor`: after `toggle` `palmMute` on a note, `state.beat.techniques` contains `palmMute`, and `hasNote` is true. On an empty string `hasNote` is false.
  - `operations.test.ts`: `deleting the only note of a grace beat removes the grace beat`.
  - `engine_bridge_test.dart`: `technique commands serialise their op`; and `parses an edit state` covers `techniques: ['palmMute']`, `dynamic: 'pp'`, `tuplet: 3` and `hasNote: true`.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test; flutter test test/unit/engine`
Expected: FAIL: unknown op `toggle`; `Toggle` not defined.

- [ ] **Step 3: Implement.**
  - `runCommand` dispatches the four new ops. Its existing whole-staff shape comparison already treats a no-op as no edit. Extend `shape` with each note's and beat's technique fingerprint (`activeTechniques`, dynamics, tuplet, grace), so toggles count as changes.
  - `EditSession.state` fills the new beat fields.
  - In `deleteNote`, a grace beat that loses its last note is removed rather than becoming a rest.

- [ ] **Step 4: Run the tests and suites**

Run: `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && flutter test --timeout 60s && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A engine lib test
git commit -m "feat: technique, dynamic, tuplet and grace commands"
```

---

### Task 3: Editor state for techniques

**Files:**
- Modify: `lib/features/editor/editor_cubit.dart`
- Test: `test/unit/features/editor/editor_cubit_test.dart`

**Interfaces:**
- Consumes: Task 2's Dart types.
- Produces: `EditorState` gains `techniques` (`Set<String>`), `dynamic` (`String?`), `tuplet` (`int`, default 1) and `hasNote` (`bool`), taken from each reply. New `EditorCubit` methods `toggle(String technique)`, `setDynamic(String dynamic)`, `setTuplet(int tuplet)` and `addGrace()` send the matching commands, only when a cursor is placed.

- [ ] **Step 1: Write the failing tests**:
  - `the state follows the techniques at the cursor`: a reply with `techniques: ['bend'], dynamic: 'mf', tuplet: 3, hasNote: true` sets those fields.
  - `toggle sends the technique`: `toggle('slide')` sends `Toggle('slide')`.
  - `technique commands wait for a cursor`: without a position, `toggle`, `setDynamic`, `setTuplet` and `addGrace` send nothing.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/unit/features/editor/editor_cubit_test.dart`
Expected: FAIL: `toggle` not defined.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run the tests and suite**

Run: `flutter test --timeout 60s && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: editor state for techniques, dynamics and tuplets"
```

---

### Task 4: The palette's technique groups

**Files:**
- Modify: `lib/features/editor/palette.dart`, `lib/features/editor/smufl.dart`, `lib/l10n/app_en.arb`
- Test: `test/widget/editor/palette_test.dart`

**Interfaces:**
- Consumes: Task 3's `EditorState` fields and methods.
- Produces: palette groups after Dots, in the order of the approved mockup (`palette-v3.html`):

  | Group | Chips |
  |---|---|
  | Dots (extended) | dot, double dot, triplet, quintuplet, sextuplet, tie, grace note |
  | Accidentals | double flat, flat, natural, sharp, double sharp |
  | Dynamics | ppp, pp, p, mp, mf, f, ff, fff, crescendo, diminuendo |
  | Guitar techniques | H/P, slide, bend, vibrato, P.M., let ring, dead note, ghost note, N.H., A.H., tapping, pick up, pick down, tremolo picking |
  | Articulation | accent, marcato, staccato, tenuto, fermata |

  New `Smufl` constants (Bravura code points):
  - **tuplets:** `` (3), `` (5), `` (6);
  - **grace:** `graceNoteAcciaccaturaStemUp` ``;
  - **accidentals:** double flat ``, flat ``, natural ``, sharp ``, double sharp ``;
  - **dynamics:** ppp ``, pp ``, p ``, mp ``, mf ``, f ``, ff ``, fff ``;
  - **articulations:** accent ``, marcato ``, staccato ``, tenuto ``, fermata ``;
  - **techniques:** vibrato `wiggleVibrato` ``, dead note `noteheadXBlack` ``, pick down `stringsDownBow` ``, pick up `stringsUpBow` ``, tremolo `tremolo3` ``.

  The other chips are text, as Guitar Pro prints them: `H/P`, `sl.`, a ⤴ for bend, `P.M.`, `let ring`, `( )` for ghost, `N.H.`, `A.H.`, `T`; the tie is `‿`, crescendo `cresc.` and diminuendo `dim.`.

- [ ] **Step 1: Write the failing tests** in `palette_test.dart`:
  - `shows every technique group`: headings `ACCIDENTALS`, `DYNAMICS`, `GUITAR TECHNIQUES` and `ARTICULATION`.
  - `active techniques are selected`: a state with `techniques: {'palmMute', 'accent'}` → the `Palm mute` and `Accent` chips are selected.
  - `a technique chip toggles it`: tapping `Slide` → `toggle('slide')`.
  - `note techniques need a note on the cursor string`: with `hasNote: false`, the `Palm mute` chip is disabled, while `Tapping` (a beat technique) stays enabled.
  - `a dynamic chip sets it, and the current one is selected`: `dynamic: 'mf'` → `mf` selected; tapping `Fortissimo` → `setDynamic('ff')`.
  - `tuplets toggle`: with `tuplet: 3`, tapping `Triplet` → `setTuplet(1)`; tapping `Quintuplet` → `setTuplet(5)`.
  - `grace note adds a grace beat`: tapping `Grace note` → `addGrace()`.
  - `symbols are Bravura glyphs`: the `Sharp` chip's text is `` in the Bravura family.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/widget/editor/palette_test.dart`
Expected: FAIL: no `ACCIDENTALS` heading.

- [ ] **Step 3: Implement**, reusing the palette's `_Group`, `_Chip` and `_Glyph`. Every chip has a tooltip from l10n (`palmMute` → "Palm mute", and so on), which is also its semantics label. Note-technique chips are disabled when `!hasNote`, and every chip is disabled without a cursor.

- [ ] **Step 4: Run the tests and suite**

Run: `npm --prefix engine run build && flutter test --timeout 60s && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: palette groups for techniques, accidentals, dynamics and articulations"
```

---

### Task 5: Simulator acceptance

No new code unless a check fails; a failure goes through superpowers:systematic-debugging, and its fix needs a test that failed first.

- [ ] **Step 1: Build and install**

Run: `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted dev.edbrsk.duoscore`
Expected: build succeeds; the app launches.

- [ ] **Step 2: Owner checks**, reported back in one message:
  1. On a new song, write 5 then 7 on one string, and set H/P on the 5: an arc with **H** appears. Do the same with 7 then 5: **P**.
  2. Slide, bend, vibrato, P.M., let ring, dead note, ghost note, N.H. and A.H. each draw their mark in the tab and the notation.
  3. Bend, slide, vibrato, palm mute and dead note sound different on playback.
  4. A triplet makes three eighths fit one beat, and the bar check agrees.
  5. A grace note draws as a small note before its beat.
  6. Dynamics: pp on one beat shows once and holds until a later change.
  7. Accent, marcato, staccato, tenuto and fermata draw over the notes.
  8. Undo steps back through these.
  9. The "(DuoScore)" copy opens in Guitar Pro 8 with every one of these marks.

- [ ] **Step 3: Record the results** in the ledger, one line per check, and fix any failure as described above.

---

## Owner feedback, round 1

From the first simulator check:
- **H/P stays as in Guitar Pro.** It belongs to the first note of the pair; on the second note the chip adds the next link, so legato runs chain.
- **Added: a bend picker (Task 6).**
- **Added: tuplets continue (Task 7).**
- **Still later:** a time signature per bar (Plan 5); export and share (Plan 6). The "(DuoScore)" copy is already in Files › On My iPhone › DuoScore.

### Task 6: Bend types and amounts

**Files:**
- Modify: `engine/src/protocol.ts`, `engine/src/editing/techniques.ts`, `engine/src/editing/commands.ts`, `engine/src/editing/session.ts`, `lib/engine/protocol.dart`, `lib/features/editor/editor_cubit.dart`, `lib/features/editor/palette.dart`, `lib/l10n/app_en.arb`
- Test: `engine/test/editing/techniques.test.ts`, `engine/test/editing/session.test.ts`, `test/unit/engine/engine_bridge_test.dart`, `test/unit/features/editor/editor_cubit_test.dart`, `test/widget/editor/palette_test.dart`

**Interfaces:**
- Produces (protocol):
  - `type BendKind = 'bend' | 'bendRelease' | 'prebend' | 'prebendRelease'`. There is no Release: Guitar Pro reads one only on a tied note after a bend, and elsewhere it reads as a pre-bend and release;
  - `type Bend = { kind: BendKind; amount: number }`, where `amount` is in quarter tones, from 1 (¼) to 12 (3 tones);
  - `EditCommand` gains `{ op: 'setBend'; bend: Bend | null }`, where null removes the bend;
  - `EditState.beat` gains `bend: Bend | null`. It is null for no bend, and for a bend shape outside the four kinds.
- Produces (engine), in `techniques.ts`:
  - `setBend(score, at, bend: Bend | null)`, a no-op on a string with no note;
  - `bendAt(score, at): Bend | null`.

  The `bend` technique reads as on for any bend, imported shapes included.
- Produces (Dart):
  - `SetBend(String? kind, int amount)`;
  - `EditState` and `EditorState` gain `bendKind` (`String?`) and `bendAmount` (`int`, default 4);
  - `EditorCubit.setBend(String? kind, int amount)`, which waits for a cursor.
- **The bend points** are in alphaTab's offset 0–60 and value in quarter tones, with `a` the amount. Each shape has at most four points, because alphaTab writes no bend with more:

  | Kind | Points |
  |---|---|
  | `bend` | (0, 0) (15, a) (60, a) |
  | `bendRelease` | (0, 0) (15, a) (30, a) (45, 0) |
  | `prebend` | (0, a) (60, a) |
  | `prebendRelease` | (0, a) (15, a) (45, 0) |

- **Palette.** The Bend chip opens a menu instead of toggling. The menu has:
  - a Type row of four chips: Bend, Bend and release, Pre-bend, Pre-bend and release;
  - an Amount row of twelve chips: ¼ ½ ¾ full 1¼ 1½ 1¾ 2 2¼ 2½ 2¾ 3;
  - a Remove bend button.

  Choosing a type or an amount sends `setBend` straight away, with the other value as it stands. The amount defaults to full and the type to Bend.

- [ ] **Step 1: Write the failing tests.**
  - Engine:
    - `each bend kind sets its points`: every kind at amount 8 gives the table's points, and `bendAt` reads it back.
    - `a bend survives the .gp round-trip`: every kind at amounts 2 and 12, read back with `bendAt`.
    - `setBend null removes the bend`.
    - `an out-of-range amount is refused`: 0 and 13 throw.
    - `the state tells the bend at the cursor`.
  - Dart:
    - `SetBend` serialises, and `null` sends `bend: null`;
    - the edit state parses `bend`;
    - the cubit follows the bend and waits for a cursor;
    - in the palette, `the bend chip opens the bend menu`: tapping Bend, then `Bend and release`, then `1½`, gives `setBend('bendRelease', 4)` and then `setBend('bendRelease', 6)`.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run all suites**, with `flutter analyze`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: bend types and amounts`.

### Task 7: Tuplets continue

**Files:**
- Modify: `engine/src/editing/operations.ts`
- Test: `engine/test/editing/operations.test.ts`

- [ ] **Step 1: Write the failing test** `a new beat continues the tuplet`. On a triplet eighth that ends the voice, moving right adds a triplet eighth rest. After three triplet eighths that fill the bar, moving right goes to the next bar.
- [ ] **Step 2: Run it to verify it fails.**
- [ ] **Step 3: Implement.** `move` right copies `tupletNumerator` and `tupletDenominator` onto the new rest.
- [ ] **Step 4: Run all suites.**
- [ ] **Step 5: Commit** `feat: new beats continue the tuplet`.

Then repeat Task 5's checks 3 and 4, plus:
10. A bend and release on fret 8, set to 2 tones, rises to fret 12's pitch and comes back.
11. Typing three triplet eighths in a row needs one tap on Triplet.
