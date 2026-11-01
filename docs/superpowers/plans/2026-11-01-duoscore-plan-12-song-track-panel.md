# Song | Track Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The right panel's upper part becomes Song | Track tabs, with four notation views, a tone dropdown, title and artist edited in place, and export; the title row above the sheet goes.

**Architecture:** The engine learns slash and numbered staff views and an artist field with a `setArtist` edit. The app carries the two views through `TrackPractice` (DuoScore's per-song record) and the artist through `SongSummary`. `TrackInfoPanel` gets a Song | Track header over the existing fold, and the score page loses `_TitleRow`, passing export into the panel.

**Tech Stack:** TypeScript + alphaTab 1.6.1 (engine, vitest), Flutter + flutter_bloc (app, flutter_test + mocktail).

**Spec:** `docs/superpowers/specs/2026-11-01-duoscore-song-track-panel-design.md`

## Global Constraints

- Branch `panel-split` (holds the two-part panel this builds on).
- Rerun `npm --prefix engine run build` after any engine change, before a simulator build.
- No comments that restate code; only a non-obvious why, one line.
- `dart format` only on touched files; never prettier on the engine; stage paths explicitly (the owner's Xcode changes stay out).
- Standard or Tab always stays on; slash and numbered add to them.
- A field left unchanged saves nothing; an empty title is never saved; an empty artist clears it.
- Opening a song shows standard and tab, slash and numbered off, until the owner's saved choice says otherwise.

## Review Focus

1. Large text (`TextScaler.linear(1.3)`): the Song | Track switch and the four view keys stay on one line in the 240 pt panel.
2. A title or artist field that's focused when the part folds, the tab switches or the song changes: the typed text is either saved or dropped, never sent to the next song.
3. Undo or redo of a title or artist change: an unfocused field shows the song's value again.
4. An untitled song: focusing and leaving the Title field sends no edit.
5. The play-only panel at the outer screen's 382 pt width: both tabs fit, export works, nothing edits.

---

### Task 1: Slash and numbered staff views in the engine

**Files:**
- Modify: `engine/src/protocol.ts:41` (`StaffView`)
- Modify: `engine/src/staves.ts`
- Test: `engine/test/staves.test.ts`

**Interfaces:**
- Produces: `StaffView = { index: number; notation: boolean; tab: boolean; slash: boolean; numbered: boolean }`; `setStaves` throws `'a track needs notation or tab'` when both `notation` and `tab` are false.

- [ ] **Step 1: Write the failing tests** in `staves.test.ts`:
  - `setStaves draws slash and numbered alongside tab`: `setStaves(score, [{ index: 0, notation: false, tab: true, slash: true, numbered: true }])` → staff 0 has `showSlash` and `showNumbered` true, `showTablature` true, `showStandardNotation` false.
  - `slash or numbered alone is refused`: `{ notation: false, tab: false, slash: true, numbered: false }` throws `'a track needs notation or tab'`.
  - `opening shows notation and tab only`: a score whose staff has `showSlash = showNumbered = true` → after `showNotationAndTab`, both false and notation and tab true.
  - Existing tests that build a `StaffView` get `slash: false, numbered: false`.
- [ ] **Step 2: Run** `npm --prefix engine test -- staves` → FAIL (new fields not applied).
- [ ] **Step 3: Implement** in `staves.ts`: `setStaves` sets `showSlash`/`showNumbered`; `showNotationAndTab` sets both false. Update the type in `protocol.ts`; fix `npx tsc --noEmit` errors in callers (`file_export.ts` passes views through unchanged).
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit)` → all pass, no type errors.
- [ ] **Step 5: Commit** `feat(engine): slash and numbered staff views`.

### Task 2: Artist in the engine

**Files:**
- Modify: `engine/src/protocol.ts` (`SongSummary`, `EditCommand`)
- Modify: `engine/src/summary.ts`, `engine/src/editing/commands.ts`, `engine/src/editing/session.ts:74`, `engine/src/main.ts:420`
- Test: `engine/test/summary.test.ts`, `engine/test/editing/commands.test.ts`, `engine/test/editing/session.test.ts`

**Interfaces:**
- Produces: `SongSummary.artist: string` (trimmed `score.artist`, `''` when none); `EditCommand` `{ op: 'setArtist'; artist: string }`.

- [ ] **Step 1: Write the failing tests:**
  - summary: a score with `artist = '  Rabea Massaad '` → `summarizeScore(...).artist === 'Rabea Massaad'`; none → `''`.
  - commands: `setArtist` with `'  Rabea '` → `edited` true, `score.artist === 'Rabea'`; the same artist again → `edited` false; `''` → `edited` true, artist cleared; undo restores the previous artist.
  - session: `session.command(s, { op: 'setArtist', artist: 'X' })` without a cursor → `{ edited: true }` (as `setTitle`).
  - Guitar Pro keeps it: export with `Gp7Exporter`, reload, `artist` equals.
- [ ] **Step 2: Run** `npm --prefix engine test -- summary commands session` → FAIL.
- [ ] **Step 3: Implement:** `summarizeScore` adds `artist`; `runCommand` case `setArtist` sets `score.artist = command.artist.trim()`; `shape` includes `score.artist` beside `score.title`; `session.command` handles `setArtist` with `setTitle`; `main.ts` skips `mixer.regenerate()` for both. Fix every other `SongSummary` literal `tsc` flags.
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit)` → all pass.
- [ ] **Step 5: Commit** `feat(engine): the song's artist, read and edited`.

### Task 3: Views and artist in the app's model

**Files:**
- Modify: `lib/engine/protocol.dart` (`StaffView`, `SongSummary`, add `SetArtist`)
- Modify: `lib/features/editor/editor_cubit.dart` (`setArtist`)
- Modify: `lib/features/playback/practice_settings.dart` (`TrackPractice`)
- Modify: `lib/features/playback/playback_cubit.dart` (`setStaffView`, the two `setStaves` call sites)
- Modify: `lib/features/export/song_exporter.dart:111`
- Test: `test/unit/engine/protocol_test.dart`, `test/unit/features/playback/practice_store_test.dart`, `test/unit/features/playback/playback_cubit_test.dart`, `test/unit/features/export/song_exporter_test.dart`

**Interfaces:**
- Consumes: Task 1's `StaffView` JSON, Task 2's `artist` and `setArtist`.
- Produces:
  - `StaffView({required int index, required bool notation, required bool tab, bool slash = false, bool numbered = false})`.
  - `SongSummary.artist` (`String`, default `''`); `SetArtist(String artist)` → `{'op': 'setArtist', 'artist': artist}`; `EditorCubit.setArtist(String)`.
  - `TrackPractice.showSlash`, `showNumbered` (default false; JSON keys `showSlash`, `showNumbered`, absent = false).
  - `PlaybackCubit.setStaffView(int track, {required bool notation, required bool tab, required bool slash, required bool numbered})`; refuses (no change, no engine call) when `notation` and `tab` are both false.

- [ ] **Step 1: Write the failing tests:**
  - `StaffView` JSON includes `slash` and `numbered`; `SongSummary.fromJson` reads `artist`, `''` when missing; `SetArtist('A').toJson()`.
  - `TrackPractice` round-trips `showSlash`/`showNumbered`; an old record without them reads false.
  - `PlaybackCubit.setStaffView(1, notation: true, tab: true, slash: true, numbered: false)` saves the practice and sends `StaffView(index: 1, notation: true, tab: true, slash: true, numbered: false)`; with `notation: false, tab: false` sends nothing.
  - On open, a saved track with only `showSlash` changed is sent to the engine (the "hidden" filter today only checks notation and tab).
  - PDF export passes slash and numbered from the practice record.
- [ ] **Step 2: Run** `flutter test test/unit` → the new tests FAIL.
- [ ] **Step 3: Implement** to the interfaces; the open path sends a view whenever it differs from notation + tab only.
- [ ] **Step 4: Run** `flutter test && flutter analyze` → all pass, `No issues found!`.
- [ ] **Step 5: Commit** `feat(playback): slash and numbered views and the artist in the app`.

### Task 4: The Song | Track tabs and the Track tab

**Files:**
- Modify: `lib/features/settings/settings_cubit.dart` (`panelTab`)
- Modify: `lib/features/score/track_info_panel.dart`
- Modify: `lib/l10n/app_en.arb` (`song`, `track`, `trackInformation`, `musicalNotation`, `viewStandard`, `viewTab`, `viewSlash`, `viewNumbered` and their full-name tooltips)
- Test: `test/unit/features/settings/settings_cubit_test.dart`, `test/widget/score/track_info_panel_test.dart`

**Interfaces:**
- Consumes: Task 3's `setStaffView`, `TrackPractice.showSlash/showNumbered`.
- Produces: `enum PanelTab { song, track }`; `AppSettings.panelTab` (default `track`, JSON `panelTab` by name); `SettingsCubit.setPanelTab(PanelTab)`.

- [ ] **Step 1: Write the failing tests:**
  - settings: `panelTab` defaults to track and persists `song`.
  - `the upper part opens on the remembered tab`: `panelTab: song` → Title field shown, view keys not.
  - `a tab tap switches and is remembered`: tap Song → `setPanelTab(PanelTab.song)`.
  - `a tab tap while folded unfolds`: `trackDetailsFolded: true`, tap Track → `setTrackDetailsFolded(folded: false)` and `setPanelTab(track)`.
  - `the four views show the track's choice`: practice `showSlash: true` → Slash key selected (`Key('view-selected')`), Numbered not.
  - `a view key toggles it`: tap Numbered → `setStaffView(1, notation: true, tab: true, slash: false, numbered: true)`.
  - `the last of Standard and Tab can't be turned off`: practice `showTab: false` → Standard key's tap sends nothing; Slash still toggles.
  - `tuning and strings share one line`: finds `E♭ A♭ D♭ G♭ B♭ E♭ · 6 strings`, and `Retune…`.
  - `tone is a dropdown`: `DropdownButton<Tone>` with value overdrive; choosing High gain → `setTone(1, Tone.highGain)`; no `RadioListTile<Tone>`.
  - `the switch and the view keys stay on one line at large text`: textScale 1.3, every label's paragraph height equals its one-line intrinsic height (as the Frets | Chords test).
  - Existing tests move to the new finders (rename by tooltip, Retune, report card, notation).
- [ ] **Step 2: Run** `flutter test test/widget/score/track_info_panel_test.dart test/unit/features/settings` → FAIL.
- [ ] **Step 3: Implement:** the upper part's header is a `SegmentedButton<PanelTab>` (labels in a one-line `FittedBox`, as `_PadSwitch`) beside the fold chevron; the Track tab body is Information (name ✎), Musical notation (four `PadKey`-style toggle keys in a row, tooltips with the full names, then the tuning line, Retune, report), Tone (`DropdownButton<Tone>` as in Settings).
- [ ] **Step 4: Run** `flutter test && flutter analyze` → all pass.
- [ ] **Step 5: Commit** `feat(score): Song | Track tabs, four notation views and a tone dropdown`.

### Task 5: The Song tab, the play-only panel and the sheet without the title row

**Files:**
- Modify: `lib/features/score/track_info_panel.dart` (Song tab, `onExport`)
- Modify: `lib/features/score/score_page.dart` (remove `_TitleRow`, floating ☰, pass `onExport`)
- Modify: `lib/l10n/app_en.arb` (`songInformation`, `title`, `artist`, `export`)
- Test: `test/widget/score/track_info_panel_test.dart`, `test/widget/score/score_page_test.dart`

**Interfaces:**
- Consumes: Task 3's `SongSummary.artist`, `EditorCubit.setTitle/setArtist`; `ExportButton(onExport:, canExportPdf:)`.
- Produces: `TrackInfoPanel({bool editable = true, Future<void> Function(ExportFormat format, Rect anchor)? onExport})`.

- [ ] **Step 1: Write the failing tests:**
  - panel, Song tab: fields show title and artist; typing `Riff` in Title and submitting → `setTitle('Riff')`; losing focus after typing in Artist → `setArtist(...)`; focus and leave unchanged → no call; clearing Title and submitting → no call and the field shows the title again; clearing Artist → `setArtist('')`.
  - `a new summary refreshes an unfocused field` (undo): emit a summary with another title → the field shows it.
  - `an edit in progress is saved when the tab switches` (Review Focus 2): type in Artist, tap Track → `setArtist` called once.
  - Song tab has `ExportButton`; `canExportPdf` false for a drums-only song.
  - play-only (`editable: false`): Song | Track tabs, no fold chevron, title and artist as `Text` (no `TextField`), `ExportButton` present, the Track tab's view keys and tone work, no Retune, no rename; at 382 pt width at 1.3 text, no overflow.
  - score page: no `Change title` tooltip and no `ExportButton` above the sheet; in Split View without a bar, the ☰ (`find.byTooltip` of the panel button) is on screen at the top end and opens the panel; export reaches `onExport` from the panel's Song tab.
  - Replace the score-page tests about the title row (`the export button shows beside the title…`, `a long title beside the export button…`, `tapping the title changes it`, `the title can't be changed`) with these.
- [ ] **Step 2: Run** `flutter test test/widget/score` → FAIL.
- [ ] **Step 3: Implement:** Song tab fields are `TextField`s owned by a `StatefulWidget` with controllers and focus nodes; commit on `onSubmitted` and on focus loss, and in `dispose` when the text differs (covers fold, tab switch and song change); compare trimmed text to the summary value. When not focused, a new summary value replaces the controller text. The score page drops `_TitleRow`; the ☰ for Split View without a bar is a `PositionedDirectional(top:, end:)` over the sheet, inset by the top padding; `onExport` goes to both panels.
- [ ] **Step 4: Run** `flutter test && flutter analyze` → all pass.
- [ ] **Step 5: Engine build and simulator:** `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch --terminate-running-process booted dev.edbrsk.duoscore` → app launches.
- [ ] **Step 6: Commit** `feat(score): the Song tab with title, artist and export; the sheet loses its title row`.
