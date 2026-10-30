# DuoScore Plan 5b: Song Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write a song's form the way Guitar Pro does: repeat signs with a play count, alternate endings, and segno, coda, Fine and the D.C./D.S. jumps. All of them are drawn, followed by playback, and saved in the `.gp` copy. Inserting and deleting bars keeps them in place.

**Architecture:**
- **The structure model** (`engine/src/editing/structure.ts`) sets the alphaTab `MasterBar` fields: `isRepeatStart`, `repeatCount`, the `alternateEndings` bitmask and `directions`. It then calls `Score.rebuildRepeatGroups()` and `finishEdit`.
- **Bar edits** (`bar_structure.ts`) carry repeat signs, sections and directions across insert and delete.
- **The Bar palette group** gains four chips that open menus, as in Plan 5a.

**Tech Stack:** as Plan 5a. Checked before writing this plan in alphaTab 1.6.1:
- Playback follows repeats, endings and every jump. A jump without its target (D.S. without a segno, al Coda without a coda) plays on without looping.
- All of these fields survive `Gp7Exporter` and re-import.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`, Editor › Palette groups › Bar: "repeat start/end, alternate ending, segno/coda".

**Branch:** `plan-5b-structure`, from `main`.

## Global Constraints

Plans 1–5a's Global Constraints all apply. In addition:

- **Everything here belongs to the bar of the whole song** (`MasterBar`), so it applies to every track.
- **Repeat end:** `repeatCount` is the number of times the section plays, 2 to 8; 0 removes the sign. A repeat end without a start repeats from the song's start, or from the end of the repeat before it, as alphaTab plays it. A jump on a repeat-end bar fires on the first pass, which is also alphaTab's playback.
- **Alternate endings:** a set of ending numbers from 1 to 8, stored as alphaTab's bitmask, where ending *n* is bit *n*−1. The empty set removes the bracket.
- **Directions offered:**

  | Id | alphaTab `Direction` | Kind |
  |---|---|---|
  | `segno` | `TargetSegno` | target |
  | `coda` | `TargetCoda` | target |
  | `fine` | `TargetFine` | target |
  | `daCapo` | `JumpDaCapo` | jump |
  | `daCapoAlFine` | `JumpDaCapoAlFine` | jump |
  | `daCapoAlCoda` | `JumpDaCapoAlCoda` | jump |
  | `dalSegno` | `JumpDalSegno` | jump |
  | `dalSegnoAlFine` | `JumpDalSegnoAlFine` | jump |
  | `dalSegnoAlCoda` | `JumpDalSegnoAlCoda` | jump |
  | `toCoda` | `JumpDaCoda` | jump |

  - **Targets** toggle independently.
  - **A bar holds at most one jump.** Choosing a jump replaces the bar's other jump.
  - **Directions outside the table**, such as a double coda from an imported file, are kept untouched and never listed.
- **Deleting a bar keeps the song's form:**
  - its repeat start, segno and coda move to the next bar;
  - its repeat end, its jump and its Fine move to the previous bar, because playback stops after the bar with Fine;
  - its section marker moves to the next bar, unless that bar has its own;
  - none of these overwrites one the receiving bar already has;
  - a one-bar repeat, with its start and end on the deleted bar, goes with the bar.
- **Inserting a bar:** the new bar takes the alternate endings of the bars on both sides when those two bars share the same non-empty set. It never takes a repeat sign or a direction.
- **Every structure command moves ticks:** `movesTicks` is true for them, so the loop is cleared.

## Review Focus

1. **A jump or a repeat end without its counterpart** (D.S. with no segno, a repeat end with no start) keeps playback finite and in order. Test: Task 1 `incomplete structures still play through`.
2. **Deleting the first or last bar of a repeat** keeps the repeat around the bars that remain. Test: Task 2 `deleting the bars at a repeat's edges keeps the repeat`.
3. **Inserting inside a two-bar ending** puts the new bar in that ending. Test: Task 2 `a bar inserted inside an ending joins it`.
4. **Imported directions the palette doesn't offer** survive every structure edit. Test: Task 1 `other directions are left alone`.
5. **Every structure mark** comes back from the `.gp` round-trip and plays in the same order. Test: Task 1 `structure survives the .gp round-trip and plays the same`.

---

### Task 1: The structure model

**Files:**
- Create: `engine/src/editing/structure.ts`, `engine/test/editing/structure.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/test/fixtures.ts`

**Interfaces:**
- Produces (protocol):
  - `type DirectionId = 'segno' | 'coda' | 'fine' | 'daCapo' | 'daCapoAlFine' | 'daCapoAlCoda' | 'dalSegno' | 'dalSegnoAlFine' | 'dalSegnoAlCoda' | 'toCoda'`;
  - `type Structure = { repeatStart: boolean; repeatCount: number; endings: number[]; directions: DirectionId[] }`, where `endings` is ascending and `directions` follows the table's order.
- Produces (engine), in `structure.ts`. Each command ends with `rebuildRepeatGroups` and `finishEdit`, and returns the cursor:
  - `toggleRepeatStart(score, at)`;
  - `setRepeatEnd(score, at, count: number)`, which throws `repeat count 1 out of range` outside 0 or 2–8;
  - `setEndings(score, at, endings: number[])`, which throws `ending 9 out of range` outside 1–8;
  - `toggleDirection(score, at, direction: DirectionId)`;
  - `structureAt(score, at): Structure`, a reader;
  - `playOrder(score): number[]`, for tests and the timeline: master-bar indexes in playback order, from a `MidiFileGenerator`'s `tickLookup.masterBars`.
- Fixture `sixBars`: one 6-string track, bars `0.6.1 | 1.6.1 | 2.6.1 | 3.6.1 | 4.6.1 | 5.6.1`.

- [ ] **Step 1: Write the failing tests** in `structure.test.ts`, on `sixBars`:
  - **`a repeat plays its bars twice`:** start on bar 1, end ×2 on bar 2 gives `playOrder` `[0,1,2,1,2,3,4,5]`. With ×3: `[0,1,2,1,2,1,2,3,4,5]`.
  - **`alternate endings take their pass`:** start 1, end ×2 on bar 2 with endings `[1]`, endings `[2]` on bar 3 gives `[0,1,2,1,3,4,5]`. `structureAt(bar 2)` is `{ repeatStart: false, repeatCount: 2, endings: [1], directions: [] }`.
  - **`D.S. al Fine goes back to the segno and stops at Fine`:** segno and fine on bar 4, D.S. al Fine on bar 5, with the repeat and endings of the test before, gives `[0,1,2,1,3,4,5,4]`.
  - **`D.C. al Coda takes the coda`:** to coda on bar 1, D.C. al Coda on bar 3, coda on bar 4 gives `[0,1,2,3,0,1,4,5]`.
  - **`a bar holds one jump`:** D.C. then D.S. on bar 3 gives directions `['dalSegno']`, and toggling D.S. again gives `[]`. Segno then fine on bar 4 gives `['segno','fine']`.
  - **`toggles undo themselves`:** a repeat start toggled twice, `setRepeatEnd` 0 and `setEndings` [] all read back `structureAt` as the fixture's.
  - **`incomplete structures still play through`:** D.S. with no segno on bar 3 gives `[0,1,2,3,4,5]`. A repeat end ×2 on bar 2 with no start gives `[0,1,2,0,1,2,3,4,5]`.
  - **`other directions are left alone`:** a bar given `Direction.TargetDoubleCoda` through the model keeps it after `toggleDirection(segno)` twice, and `structureAt` doesn't list it.
  - **`out-of-range values are refused`:** repeat counts 1 and 9, ending 0 and ending 9.
  - **`structure survives the .gp round-trip and plays the same`:** every mark above set on one song gives the same `structureAt` for every bar after `Gp7Exporter` → `ScoreLoader`, and the same `playOrder`.

- [ ] **Step 2: Run them to verify they fail**

Run: `npm --prefix engine test`
Expected: FAIL: `../../src/editing/structure` not found.

- [ ] **Step 3: Implement `structure.ts`.**

- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(engine): repeats, endings and directions`

---

### Task 2: Insert and delete keep the form

**Files:**
- Modify: `engine/src/editing/bar_structure.ts`
- Test: `engine/test/editing/bar_structure.test.ts`

**Interfaces:**
- Consumes: Task 1's `structureAt`, `playOrder` and `sixBars`.
- Produces: no new names. `insertBar` and `deleteBar` follow the Global Constraints.

- [ ] **Step 1: Write the failing tests**, on `sixBars`:
  - **`deleting the bars at a repeat's edges keeps the repeat`:** with a start on bar 1 and an end ×2 on bar 3, deleting bar 1 leaves the start on the new bar 1 and the order `[0,1,2,1,2,3,4]`. On a fresh song, deleting bar 3 leaves the end on bar 2, with `[0,1,2,1,2,3,4]`.
  - **`a one-bar repeat goes with its bar`:** a start and end on bar 2, then deleting bar 2, leaves no repeat.
  - **`deleting a bar keeps its marks`:** with a segno and a section `A` on bar 2 and a D.S. on bar 4, deleting bar 2 puts the segno and the section on the new bar 2. Deleting bar 4 puts the D.S. on bar 3.
  - **`a carried mark never replaces one already there`:** with a section `A` on bar 2 and a section `B` on bar 3, deleting bar 2 leaves `B` on the new bar 2.
  - **`a bar inserted inside an ending joins it`:** endings `[1]` on bars 2 and 3, then inserting at bar 3, gives the new bar 3 endings `[1]`. Inserting at bar 2 (the ending's first bar) gives the new bar no endings.
  - **`an inserted bar takes no repeat or direction`:** inserting at a bar with a repeat start and a segno leaves them on the bar that moved, and the new bar reads `structureAt` empty.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement**, in `insertBar` and `deleteBar`, before `relink`.
- [ ] **Step 4: Run** the engine suite and `tsc`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(engine): bar edits keep repeats, endings, directions and sections`

---

### Task 3: Structure over the bridge and in the editor

**Files:**
- Modify:
  - engine: `engine/src/protocol.ts`, `engine/src/editing/commands.ts`, `engine/src/editing/session.ts`;
  - Dart: `lib/engine/protocol.dart`, `lib/features/editor/editor_cubit.dart`.
- Test:
  - engine: `engine/test/editing/commands.test.ts`, `engine/test/editing/session.test.ts`;
  - Dart: `test/unit/engine/engine_bridge_test.dart`, `test/unit/features/editor/editor_cubit_test.dart`.

**Interfaces:**
- Consumes: Task 1.
- Produces (protocol):
  - `EditCommand` gains `{ op: 'toggleRepeatStart' }`, `{ op: 'setRepeatEnd'; count: number }`, `{ op: 'toggleEnding'; ending: number }` and `{ op: 'toggleDirection'; direction: DirectionId }`;
  - `EditState` gains `structure: Structure | null`, which is null without a cursor;
  - `movesTicks` is true for all four commands;
  - `shape` adds each bar's repeat start, repeat count, endings and directions.
- Produces (Dart):
  - commands `ToggleRepeatStart()`, `SetRepeatEnd(int count)`, `ToggleEnding(int ending)` and `ToggleDirection(String direction)`;
  - `EditState` and `EditorState` fields `repeatStart` (`bool`), `repeatCount` (`int`), `endings` (`List<int>`) and `directions` (`Set<String>`);
  - `EditorCubit` methods `toggleRepeatStart()`, `setRepeatEnd(int count)`, `toggleEnding(int ending)` and `toggleDirection(String direction)`, which wait for a cursor.

- [ ] **Step 1: Write the failing tests:**
  - **engine:**
    - `structure commands are edits and undo`;
    - `structure commands move ticks`;
    - `the state tells the bar's structure`.
  - **Dart:**
    - each command serialises;
    - `parses an edit state` covers `structure`;
    - the cubit follows the structure, sends each command, and waits for a cursor.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && flutter test --timeout 60s && flutter analyze`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: structure commands over the bridge and in the editor`

---

### Task 4: The palette's structure chips

**Files:**
- Modify: `lib/features/editor/bar_menus.dart`, `lib/features/editor/palette.dart`, `lib/features/editor/smufl.dart`, `lib/l10n/app_en.arb`
- Test: `test/widget/editor/bar_menus_test.dart`, `test/widget/editor/palette_test.dart`

**Interfaces:**
- Consumes: Task 3.
- Produces: four chips appended to the Bar group, after Tempo. Every chip needs a cursor.

  | Chip | Label | Does |
  |---|---|---|
  | Repeat start | `Smufl.repeatLeft` U+E040 | toggles, and is selected when `repeatStart` |
  | Repeat end | `Smufl.repeatRight` U+E041 | opens a menu of count chips ×2 to ×8, with the current count selected, plus No repeat (sends 0) |
  | Alternate ending | `1.`, or the endings joined, e.g. `1.2.` | opens a menu of ending chips 1 to 8; each tap sends `toggleEnding` for that ending, so quick taps never undo each other |
  | Directions | `Smufl.segno` U+E047, selected when the bar has any listed direction | opens a menu with a Targets row (Segno U+E047, Coda U+E048, `Fine`) and a Jumps row (`D.C.`, `D.C. al Fine`, `D.C. al Coda`, `D.S.`, `D.S. al Fine`, `D.S. al Coda`, `To Coda`). Each chip toggles its direction and shows it selected. |

- [ ] **Step 1: Write the failing tests:**
  - **`palette_test.dart`:**
    - `the structure chips need a cursor`;
    - `repeat start toggles and shows its state`.
  - **`bar_menus_test.dart`:**
    - `a repeat count sets the repeat end, and No repeat removes it`: ×3 sends `setRepeatEnd(3)`; No repeat sends 0.
    - `ending chips add and remove endings`: with `[1]`, tapping 2 sends `toggleEnding(2)`, and tapping 1 sends `toggleEnding(1)`.
    - `direction chips toggle and show the bar's directions`: with `{'segno'}`, Segno is selected, and tapping `D.S. al Coda` sends `toggleDirection('dalSegnoAlCoda')`.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement** with `_MenuChip` and `PaletteChip`, with l10n tooltips.
- [ ] **Step 4: Run** `npm --prefix engine run build && flutter test --timeout 60s && flutter analyze`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: palette chips for repeats, endings and directions`

---

### Task 5: Simulator acceptance

No new code unless a check fails. A failure goes through superpowers:systematic-debugging, and its fix needs a test that failed first.

- [ ] **Step 1: Build and install**

Run: `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted dev.edbrsk.duoscore`
Expected: build succeeds; the app launches.

- [ ] **Step 2: Owner checks**, reported back in one message:
  1. A repeat over bars 2–3 ×2 draws its signs, and playback (with the cursor) goes 1 2 3 2 3 4.
  2. Endings 1. and 2. draw their brackets, and the second pass skips ending 1.
  3. Segno, Coda, Fine and the D.C./D.S. jumps draw their marks, and playback follows them.
  4. Deleting a repeat's first bar keeps the repeat, and inserting inside an ending keeps the bracket over the new bar.
  5. Undo reverts each of these.
  6. The "(DuoScore)" copy opens in Guitar Pro 8 with the same repeats, endings and directions, and plays in the same order.

- [ ] **Step 3: Record the results** in the ledger, one line per check, and fix any failure as described above.
