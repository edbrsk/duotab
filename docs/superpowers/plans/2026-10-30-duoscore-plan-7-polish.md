# DuoScore Plan 7: Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the deferred review findings that are still present after triage. Each is a small, contained correction.

**Architecture:** No new subsystems. Each task gathers the fixes in one area: song edits, bars, tracks, cursor and input, engine and playback, storage and library, export, and import with security. Item numbers (#N) refer to the triage list. The final message reports every item as fixed, already fixed, or not fixed with its reason.

**Tech Stack:** as Plan 6b, plus the library change (`OwnedFiles`, `SongExporter.shareFile`).

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`. Every item serves an existing requirement or anti-goal; none adds a feature.

**Branch:** `plan-7-polish`, from `main`.

## Global Constraints

Plans 1–6b's Global Constraints, and the library change's rules, all apply. In addition:

- **Verify first:** items triage didn't check (#9, #11, #12, #26, #45, #47, #48) get a check before any change. If an item proves fixed, it goes in the ledger as `already fixed` with evidence, and gets no code.
- **Every code change gets a test that fails first,** except Swift (#13, #17, #33, #38), which has no test target. Those are verified by `flutter build ios --simulator` and listed for the owner's checks.
- **No item changes what a working song sounds like or how it is saved,** beyond the stated correction.
- **Not fixed,** each a ruling for the owner:
  - **#4** is alphaTab's re-import of 3-point bends; the `.gp` file is correct.
  - **#14** is alphaTab not drawing a one-beat selection.
  - **#25** is a copy-time cost the owner never feels.
  - **#46 and #54:** rendering stays on the page thread, because tap hit-testing reads its layout.
  - **#57** is a stale popover anchor, cosmetic.
  - **#62** needs 15 tracks.
  - **#21** (what's left of it): a tap outside the loop clears it, as in Guitar Pro.

## Review Focus

1. **A change that `shape` can't see** (#1, #6, #16) must now count as an edit: it makes the "(DuoScore)" copy and an undo step. Test: Task 1 `every model change the palette can make is an edit`.
2. **Deleting the bar that ends an outer repeat** right after an inner repeat's end is refused, and the song is unchanged. Test: Task 2 `deleting an outer repeat's last bar next to an inner end is refused`.
3. **A damaged `practice.json` or `owned.json`** is kept aside and never overwritten. Test: Task 6 `a damaged store is kept aside before it is written`.
4. **The asset server refuses requests without the launch token, or with a foreign Host,** and the engine page still loads songs and fonts. Tests: Task 8 `a request without the token is refused` and `a foreign Host is refused`; the owner opens a song and exports a PDF.
5. **Two digits typed quickly on one note** make one undo step, and a tap elsewhere between them gives two single frets. Test: Task 4 `two digits make one fret and one undo step; a tap between them splits them`.

---

### Task 1: Changes that must count as edits (#1, #6, #16)

**Files:** `engine/src/editing/commands.ts` (`shape`), `engine/src/editing/bars.ts`, `engine/test/editing/commands.test.ts`

- [ ] **Step 1: Write the failing tests:**
  - `every model change the palette can make is an edit`. Each of these gives `edited: true` and one undo step:
    - (a) 4/4 on a bar showing "C" (common time);
    - (b) `natural` on a ForceNatural note (alphaTex);
    - (c) an octave retune where every note is unplayable, which still changes the chord diagrams and the tuning name.
  - `4/4 on a common-time bar that already reads 4/4 changes nothing`: `setTimeSignature` with the same numerator and denominator leaves `timeSignatureCommon` as it is, so `edited` is false.
- [ ] **Step 2: Run them to verify they fail:** `npm --prefix engine test -- commands`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `shape` adds `timeSignatureCommon`, each note's `accentuated` and `accidentalMode`, the staff's `stringTuning.name`, and every chord's `strings` and `showDiagram`.
  - `setTimeSignature` only clears `timeSignatureCommon` when the numerator or denominator changes.
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`. Expected: all pass.
- [ ] **Step 5: Commit** `fix(engine): every change to the song counts as an edit`

---

### Task 2: Bars (#3, #22, #27, #29, #36, #41, #44)

**Files:**
- `engine/src/editing/operations.ts` (`appendBar`), `bar_structure.ts` (`deleteBar`, `insertBar`, `carryForm`), `bars.ts` (the refill), `bar_check.ts`;
- `lib/features/editor/palette.dart`;
- tests in `engine/test/editing/*` and `test/widget/editor/palette_test.dart`.

- [ ] **Step 1: Write the failing tests:**
  - `an appended bar keeps the triplet feel` (#22).
  - `a segno and a To Coda on a deleted bar move together`: both go to the next bar, or to the previous one when the deleted bar is last (#27).
  - `deleting an outer repeat's last bar next to an inner end is refused`: it throws `this bar ends a repeat that can't move`, and the song is unchanged (#29).
  - `inserting before a pickup bar ends the pickup`: the moved bar's `isAnacrusis` becomes false, and the bar check then reports it short (#36).
  - `a pickup or free-time bar is not flagged`: the bar check skips `isAnacrusis` and free-time master bars (#41).
  - `a time signature change keeps the text and lyrics on its rests`: a removed rest's `text` and `lyrics` go to the new rest that starts at or before its tick (#44).
  - In `palette_test.dart`, `delete bar is off for a one-bar song` (#3), using `song.bars.length`.
- [ ] **Step 2: Run them to verify they fail:** `npm --prefix engine test && flutter test test/widget/editor/palette_test.dart`. Expected: FAIL on these.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && flutter test`. Expected: all pass.
- [ ] **Step 5: Commit** `fix: bar edits keep feel, form, pickups and lyrics`

---

### Task 3: Tracks (#2, #15, #31, #32, #34, #45, #50, #56)

**Files:**
- `engine/src/editing/tracks.ts`;
- `lib/features/score/add_track_dialog.dart`, `track_drawer.dart`, `track_info_panel.dart`;
- `lib/features/editor/editor_cubit.dart`, `lib/features/score/score_page.dart`, `lib/l10n/app_en.arb`;
- tests in `engine/test/editing/tracks.test.ts`, `test/unit/features/editor/editor_cubit_test.dart` and `test/widget/score/*`.

**Interfaces:**
- **Produces:**
  - `EditorCubit.failures: Stream<String>`, the engine's message for each failed command;
  - `ScorePage` shows each failure as a SnackBar, mapped by `editFailureMessage(l10n, message)`.
  - **Known messages:**
    - `no free MIDI channel` → "No MIDI channel is free for another track";
    - `a track needs a name` → "A track needs a name";
    - `the song keeps one guitar track` → "The song keeps at least one guitar track";
    - `this bar ends a repeat that can't move` → "This bar ends a repeat that can't move";
    - anything else → "Couldn't make that change".

- [ ] **Step 1: Check #45** (the stylesheet's per-track flags after a remove or move: `perTrackMultiBarRest`, displayed tuning, chord diagrams). If they're still keyed to the old track indexes, add `removing or moving a track keeps its display flags with it`.
- [ ] **Step 2: Write the failing tests:**
  - `Add track starts at the drawn track's tuning` (#2).
  - `a rename renames a derived short name too`: a short name that is empty, or a prefix of the old name, becomes the new name cut to 10 characters; a custom short name stays (#15).
  - `move and rename refuse other tracks and indexes past the end` (#50).
  - `a failed command is reported` (#32), in the cubit.
  - `a failed track edit says why`, on the score page.
  - `in Split View the drawer offers no track tools` (#34).
  - `the drawer labels and the track name field are localised` (#31, #56): new keys `muteShort` "M", `soloShort` "S" and `trackName` "Track name".
- [ ] **Step 3: Run them to verify they fail:** `npm --prefix engine test && flutter test`. Expected: FAIL on these.
- [ ] **Step 4: Implement,** then run `flutter gen-l10n`.
- [ ] **Step 5: Run** `npm --prefix engine test && flutter test && flutter analyze`. Expected: all pass, and no issues.
- [ ] **Step 6: Commit** `fix: track edits explain failures, keep short names and display flags`

---

### Task 4: Cursor and input (#8, #18, #24, #49, #63)

**Files:**
- `lib/features/editor/fret_pad.dart`, `fret_entry.dart`, `bar_menus.dart`, `palette.dart`;
- `engine/src/editing/session.ts`, `operations.ts` (`setFret`), `techniques.ts`, `overlay.ts`, `hit_test.ts`, `commands.ts`, `engine/src/protocol.ts`;
- `lib/engine/protocol.dart`, plus tests.

**Interfaces:**
- **Produces:** `SetFret(fret, {bool combine = false})`, serialised as `{ op: 'setFret', fret, combine }`. With `combine`, `runCommand` pushes no new undo step, so the snapshot from the first digit covers both.

- [ ] **Step 1: Write the failing tests:**
  - `two digits make one fret and one undo step; a tap between them splits them` (#18):
    - cubit and FretPad: "1" then "2" within 800 ms sends `SetFret(1)` then `SetFret(12, combine: true)`;
    - a cursor change between them resets the entry;
    - session: one undo returns to before the "1".
  - `a retune to fewer strings keeps the cursor on the same physical string` (#49): the cursor on string 7 of 7, retuned to 6, ends on string 6. The test is `session.test.ts` `a retune to fewer strings keeps the cursor on a real string`, extended so the mapping comes from the top.
  - `with tab hidden the cursor shows on the notation and a tap keeps the string` (#63). This uses the hit-test fixture with tab off: the cursor rect lies inside the notation staff, and the tap keeps `position.string`.
  - `imported technique variants read as on, and a tap clears them` (#24). Wide vibrato, an 8th-note tremolo, a pinch harmonic and a bend of another type each show their chip active. A tap clears them; another tap sets the palette default. A pinch harmonic shows as the artificial-harmonic chip.
  - `a clef the palette doesn't offer shows a neutral glyph` (#8).
- [ ] **Step 2: Run them to verify they fail.** Expected: FAIL on these.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `npm --prefix engine test && flutter test && flutter analyze`. Expected: all pass, and no issues.
- [ ] **Step 5: Commit** `fix: fret entry, cursor and technique chips read the song as it is`

---

### Task 5: Engine and playback (#9, #10, #26, #30, #39, #47, #48, #52, #53, #60, #61)

**Files:**
- `engine/src/main.ts`, `mixer.ts`, `touch_selection.ts`, `engine/src/editing/restore.ts`;
- `lib/features/playback/playback_cubit.dart`, `resolve_practice.dart`, `practice_settings.dart`, `track_drawer.dart`;
- `lib/l10n/app_en.arb`, plus tests.

- [ ] **Step 1: Check the unchecked items:**
  - **#9:** whether a saved tone that equals the old default tracks a later default change.
  - **#26:** whether a tone change during playback replays the count-in.
  - **#47:** whether stored speed and range are validated on load.
  - **#48:** the order of selecting and seeking for a cell tap on another track.

  Ledger each result.
- [ ] **Step 2: Write the failing tests:**
  - **#10 (made testable):** `a failed open resets the file flag`. The `fromFile`/`openedMarks` handling moves into a small `OpenState` in `engine/src/open_state.ts`.
  - **#39:** `a second open rejects the first one still waiting`, with the message `another song opened`, also in `OpenState`.
  - **#30:** `dragging a loop during playback seeks only on release`, in `touch_selection.test.ts`.
  - **#52:** `the baked level is taken when the MIDI is made`, in `mixer.test.ts`.
  - **#60:** `a load that makes MIDI twice restores after the second`, in `mixer.test.ts`.
  - **#61:** `an undo that moves the bars clears the loop`. `rangeAfterRestore(before, after, range)` in `restore.ts` returns null when the master bars' start ticks differ.
  - **#53:** `the fingering message counts only the drawn track`. `describeOpened` receives that track's count, and the open uses track `nearestGuitar(score, 0)`, as Dart draws.
  - **#9, #26, #47 and #48,** for each one Step 1 found still present:
    - **#9:** `a default tone change reaches tracks left at the default`. Practice stores a track's tone only once the owner chooses one.
    - **#26:** `a tone change while playing doesn't replay the count-in`.
    - **#47:** `a stored speed or range outside the song is dropped on load`.
    - **#48:** `a cell on another guitar track draws it before seeking`.
- [ ] **Step 3: Run them to verify they fail.** Expected: FAIL on these.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .) && flutter test && flutter analyze`. Expected: all pass, and no issues.
- [ ] **Step 6: Commit** `fix: opens, loops, mix levels and practice settings hold through edge cases`

---

### Task 6: Storage and library (#11, #20, #37, #40, #64, #65)

**Files:**
- `lib/core/storage/json_file.dart`, `lib/features/editor/owned_files.dart`, `lib/features/library/library_cubit.dart`, `library_page.dart`;
- `lib/main.dart`, `lib/core/dependency_injection.dart`, plus tests.

- [ ] **Step 1: Check #11** (a failure in `setupDependencies`).
- [ ] **Step 2: Write the failing tests:**
  - `a damaged store is kept aside before it is written` (#20). An unreadable file is renamed to `<name>.damaged-<yyyyMMddHHmmss>` on its first read, and that read returns empty.
  - `owned changes run one at a time` (#64): concurrent `addCopy` and `rename` both survive.
  - `a refresh forgets owned files that are gone` (#40): `OwnedFiles.keepOnly(Set<String> present)` drops paths and records for missing files.
  - `refreshes asked for at once run once, then once more` (#37).
  - `a song row keeps its own export state` (#65): the tiles use `ValueKey(entry.path)`.
  - **#11, if still present:** `a failed start shows what went wrong`. `main` shows a plain `MaterialApp` with the error text.
- [ ] **Step 3: Run them to verify they fail.** Expected: FAIL on these.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `flutter test && flutter analyze`. Expected: all pass, and no issues.
- [ ] **Step 6: Commit** `fix: stores survive damage and races; the library refreshes once at a time`

---

### Task 7: Export (#13, #17, #38, #51, #55, #58, #66, #67)

**Files:**
- `lib/features/export/song_exporter.dart`, `export_button.dart`, `lib/features/library/library_page.dart`;
- `ios/Runner/AppDelegate.swift`, `lib/l10n/app_en.arb`;
- tests in `engine/test/print_pages.test.ts`, `engine/test/file_export.test.ts` and `test/unit/features/export/*`.

**Interfaces:**
- **Produces:** `exportFailureMessage(l10n, Object error): String`.
  - **PlatformException:**
    - `pdf_failed` → "Couldn't make the PDF";
    - `unavailable` → "Another export is open".
  - **Engine messages:** `no guitar track` → "This song has no guitar track to print".
  - **File errors:** a `PathNotFoundException` → "The song file is missing".
  - **Anything else:** "Couldn't export".

  It replaces `'$e'` in both export SnackBars.

- [ ] **Step 1: Write the failing tests:**
  - `export errors read as messages` (#51).
  - `file names stay under 200 bytes and never start with a dot` (#58).
  - `each export keeps its own folder` (#66):
    - each export uses `exports/<microseconds>/`;
    - an export deletes the other folders only when they're older than 10 minutes.
  - `a library PDF prints the first guitar track after drums` (#67).
  - `the private sample prints every system` now applies `showNotationAndTab` first (#55).
- [ ] **Step 2: Run them to verify they fail.** Expected: FAIL on these.
- [ ] **Step 3: Implement,** including the Swift fixes:
  - **#13:** after loading the fonts, `document.fonts.check("34px alphaTab")` must be true, or the export throws `ExportError.fontMissing`;
  - **#17:** `configuration.rect = Self.page`;
  - **#38:** keep the `WKNavigation` returned by `loadHTMLString`, and finish loading only for that one.
- [ ] **Step 4: Run** `npm --prefix engine test && flutter test && flutter analyze && flutter build ios --simulator`. Expected: all pass, no issues, and the build exits 0.
- [ ] **Step 5: Commit** `fix: exports explain failures, keep their own files and A4 pages`

---

### Task 8: Import, layout and the asset server (#12, #23, #33, #35, #59)

**Files:**
- `lib/engine/asset_server.dart`, `lib/engine/engine_host.dart`, `engine/src/main.ts` (`songUrl`);
- `ios/Runner/AppDelegate.swift`, `lib/features/import/incoming_files_provider.dart`;
- `lib/presentation/workspace/workspace_layout.dart`, plus tests.

**Interfaces:**
- **Asset server:**
  - `AssetServer.start` makes a random 32-hex token for each launch;
  - every route sits under `/<token>/`;
  - `engineUri` includes the token.
- **Requests:**
  - any path outside the token gets 404;
  - a `Host` other than `127.0.0.1:<port>` gets 403.
- **Engine page:** `songUrl` becomes relative (`./songs/…`), so it inherits the token prefix.
- **Import errors:**
  - an incoming-file event may be `{ "error": "<file name>" }`;
  - `IncomingFilesProvider` exposes `failures: Stream<String>`;
  - the library shows "Couldn't import {name}".

- [ ] **Step 1: Write the failing tests:**
  - `a request without the token is refused` and `a foreign Host is refused` (#23);
  - the traversal test uses `..%2F` (#59);
  - `an import error is reported` (#33, Dart side);
  - `collapsed Split View keeps the score clear of the vertical bar` (#35);
  - **#12:** remove the doc comments that restate names (protocol.dart `BarProperties`, `loopBars`, the insert/delete/paste docs), and make the clef round-trip test start from another clef first.
- [ ] **Step 2: Run them to verify they fail.** Expected: FAIL on these.
- [ ] **Step 3: Implement,** including the Swift fix for #33: copy through `NSFileCoordinator` (`coordinate(readingItemAt:options:.forUploading)`), and send `{ "error": name }` on failure.
- [ ] **Step 4: Run the checks:**
  ```
  npm --prefix engine run build && npm --prefix engine test && flutter test \
    && flutter analyze && flutter build ios --simulator \
    && xcrun simctl install booted build/ios/iphonesimulator/Runner.app \
    && xcrun simctl launch booted dev.edbrsk.duoscore
  ```
  Expected: all pass, no issues, and the app launches.
- [ ] **Step 5: Commit** `fix: the asset server needs its launch token; imports report failures`

---

## Owner checks on the simulator

1. **Open Collateral Damage, play it, and export a PDF:** everything loads through the token-protected server.
2. **Type "1" then "2" quickly on a note, then Undo once:** the fret goes back to what it was before the "1".
3. **Hide the tab:** the cursor shows on the notation, and tapping notes moves it.
4. **Try to add a 16th track, or rename one to blank:** a message says why it can't.
5. **Turn Split View on:** the drawer shows no Add track or track menu, and the score isn't under the vertical bar.
6. **Export from the library while another export is running:** a message says another export is open.
