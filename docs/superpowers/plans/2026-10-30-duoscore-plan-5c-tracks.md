# DuoScore Plan 5c: Tracks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mix the tracks with a volume slider each, and add, remove, reorder and rename guitar tracks.

**Architecture:**
- **Volume** is a practice setting like tone. The engine plays it live through alphaTab's per-channel mix volume, and writes it into `playbackInfo.volume` so the saved copy carries it.
- **Track edits** are undoable engine commands (`engine/src/editing/tracks.ts`). The engine keeps the drawn track and reports it in every edit reply.
- **Practice settings** follow their track by its MIDI channel, so reordering, removing and undoing keep each track's tone, mute, solo, volume and staves.

**Tech Stack:** as Plan 5b. alphaTab 1.6.1:
- `Track`, `Staff`, `PlaybackInfo` (`volume` 0–16, `primaryChannel`, `secondaryChannel`, `program`);
- `api.changeTrackVolume(tracks, factor)`, a multiplier on the channel's own MIDI volume, kept per channel by the player.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`:
- Editor › Guitar tracks: "The track drawer adds, removes and reorders them, the track information panel renames them, and each has its own string count, tuning and tone. Non-guitar tracks from opened files are kept and played but cannot be edited."
- Track drawer › Mixer.
- Music engine › Practice settings.

**Branch:** `plan-5c-tracks`, from `main`.

## Global Constraints

Plans 1–5b's Global Constraints all apply. In addition:

- **Volume:**
  - It is an integer 0–16, alphaTab's and Guitar Pro's track volume. The slider shows it as 0–100% (volume ÷ 16), starting at the file's own level.
  - It is kept per song in practice settings, like tone, and written into `playbackInfo.volume`.
  - The live level is `changeTrackVolume` with factor = volume ÷ the level the current MIDI was made with. A track whose MIDI was made at 0 gets new MIDI instead.
  - A new song resets the mix volume of every channel the mixer changed, as mute and solo already are.
- **Practice settings follow their track by its primary MIDI channel.** `TrackSummary` carries `channel`. When an edit, undo or redo changes the song's tracks, each new track index takes the practice of the old track with the same channel (the first unmatched one, when channels repeat). A track with no match gets the resolved defaults. The remapped settings are saved and sent.
- **Only guitar tracks** are added, removed, moved or renamed. The song always keeps at least one guitar track.
- **Adding a track** appends it after the last track:
  - **Name:** `Guitar N`, with the smallest N no track uses.
  - **Strings and tuning:** chosen in the dialog, as in New song.
  - **Program:** the default tone's.
  - **Volume:** 12.
  - **Channels:** the lowest MIDI channel no track uses, skipping 9, as primary. The next free one, skipping 9, is secondary, or the primary again when none is left. When no channel is free, the add is refused.
  - **Bars:** one per master bar, with the first guitar track's clef and key in that bar, each filled with rests (voice 0 fitting rests).
  - **Staff:** notation and tab both shown, and `displayTranspositionPitch` −12, as Guitar Pro guitars.
  - **Drawing:** the new track becomes the drawn track, with no cursor.
- **Removing a track** removes its notes. When the drawn track is removed, the nearest guitar track (the one after it, else the one before) becomes the drawn track.
- **Moving a track** goes one step up or down in the palette's menu, using `moveTrack(from, to)`.
- **A rename** is trimmed and must not be empty. It sets `name` and leaves `shortName` alone.
- **All four are edits:** undoable, saved, and they make the "(DuoScore)" copy. None needs a cursor.

## Review Focus

1. **Reordering or removing tracks keeps each remaining track's practice.** Its tone, mute, solo, volume and staves stay with it, across undo and redo too. Test: Task 3 `practice follows its track through a move, a removal and an undo`.
2. **Removing the drawn track** leaves a guitar track drawn, and never a drum track or an index past the end. Test: Task 2 `removing the drawn track draws the nearest guitar track`.
3. **A mixer level set before a tone change** survives the MIDI rebuild that the tone change causes. Test: Task 1 `a volume survives new MIDI`.
4. **Adding a track to a song with repeats, endings and time signature changes** gives it a bar for every master bar, filled to each bar's length. Test: Task 2 `an added track fits every bar`.
5. **An added, moved or renamed track** comes back from the `.gp` round-trip. Test: Task 2 `track edits survive the .gp round-trip`.

---

### Task 1: Track volume in the engine

**Files:**
- Modify: `engine/src/protocol.ts`, `engine/src/mixer.ts`, `engine/src/summary.ts`
- Test: `engine/test/mixer.test.ts`, `engine/test/summary.test.ts`

**Interfaces:**
- Produces:
  - `TrackMix` gains `volume: number`, 0–16.
  - `TrackSummary` gains `volume: number` (`playbackInfo.volume`) and `channel: number` (`primaryChannel`).
  - `MixerApi` gains `changeTrackVolume(tracks, factor: number)`.
  - `Mixer.apply` sets `playbackInfo.volume` and the live factor.

- [ ] **Step 1: Write the failing tests:**
  - **`mixer.test.ts`**, extending the fake to record `changeTrackVolume` calls:
    - `a volume plays at its share of the MIDI level`: a track whose MIDI was made at 12, mixed at 6, gets factor 0.5, and `playbackInfo.volume` becomes 6.
    - `a volume survives new MIDI`: after a program change regenerates the MIDI, the factor sent is 1, and `playbackInfo.volume` is still 6.
    - `a track made at 0 gets new MIDI for a volume`: a track at 0 mixed at 8 regenerates.
    - `a new song resets the changed channels' volume`: their factor is 1 again.
  - **`summary.test.ts`:** `summaries tell each track's volume and channel`.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.** The mixer records, per track object, the volume each MIDI load was made with, on every `midiLoaded`.
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(engine): track volume in the mixer`

---

### Task 2: Track edits in the engine

**Files:**
- Create: `engine/src/editing/tracks.ts`, `engine/test/editing/tracks.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/src/editing/commands.ts`, `engine/src/editing/session.ts`, `engine/src/main.ts`, `engine/test/fixtures.ts`

**Interfaces:**
- Consumes: Task 1's `TrackSummary.channel`.
- Produces (engine), in `tracks.ts`:
  - `addTrack(score, options: { tuning: number[]; program: number }): number`, which returns the new track's index and throws `no free MIDI channel`;
  - `removeTrack(score, index)`, which throws `the song keeps one guitar track` and `only guitar tracks can be removed`;
  - `moveTrack(score, from, to)`;
  - `renameTrack(score, index, name)`, which throws `a track needs a name`.

  Each ends with `relink`-like index fixes (`track.index`) and `score.finish`.
- Produces (protocol):
  - `EditCommand` gains `{ op: 'addTrack'; tuning: number[]; program: number }`, `{ op: 'removeTrack'; track: number }`, `{ op: 'moveTrack'; track: number; to: number }` and `{ op: 'renameTrack'; track: number; name: string }`.
  - `EditState` gains `drawnTrack: number`.
  - `movesTicks` is true for `addTrack`, `removeTrack` and `moveTrack`.
- Produces (session): track commands run without a cursor. After each one the session updates `track` (the drawn track):
  - an added track becomes drawn;
  - other edits keep the same `Track` object drawn;
  - when the drawn track is removed, the nearest guitar track becomes drawn.

  The cursor is cleared when the drawn track changes. `restored` clamps `track` to a guitar track.
- Produces (main): after a track edit, the engine draws `score.tracks[session.track]` through `mixer.regenerate(() => api.renderScore(...))`.
- Fixture `guitarDrumsGuitar`: tracks Guitar A (6 strings), Drums and Guitar B (7 strings), with 3 bars. Bar 1 is 3/4, and bar 2 has a repeat start and end ×2.

- [ ] **Step 1: Write the failing tests** in `tracks.test.ts`:
  - **`an added track fits every bar`:** `addTrack` with a Drop D tuning appends track 3, named `Guitar 1`. It has 3 bars filled to 3840, 2880 and 3840 ticks, a 6-string tuning matching the given notes, notation and tab shown, transposition −12, volume 12, and channels unused by other tracks and not 9.
  - **`added tracks take free names and channels`:** a second add is named `Guitar 2`, and its channels differ from the first's.
  - **`removing a track removes its notes and keeps the others`:** removing Guitar B leaves 3 tracks, and Guitar A's notes are unchanged.
  - **`the song keeps a guitar track`:** removing Guitar A, then Guitar B, throws on the last one. Removing Drums throws `only guitar tracks can be removed`.
  - **`moving a track reorders and reindexes`:** moving 2 to 0 gives B, A, Drums, with indexes 0, 1, 2.
  - **`renaming trims and refuses an empty name`.**
  - **`track edits survive the .gp round-trip`:** add, move and rename, then `Gp7Exporter` → `ScoreLoader` gives the same names, string counts, tunings and order.
  - **`removing the drawn track draws the nearest guitar track`**, through `EditSession`: drawing Guitar B and removing it draws Guitar A, never Drums. With the drawn track at index 0 and track 1 removed, track 0 stays drawn.
  - **`a track edit is an edit and undoes`**, in `commands.test.ts`, for all four ops.
  - **`track commands need no cursor`**, in `session.test.ts`: an added track becomes `drawnTrack`, and the cursor is null.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.** New bars follow `insertBar`'s per-bar construction, with ids from `idSource`.
- [ ] **Step 4: Run** the engine suite and `tsc`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(engine): add, remove, move and rename guitar tracks`

---

### Task 3: Tracks and volume in Dart

**Files:**
- Modify:
  - engine bridge: `lib/engine/protocol.dart`;
  - practice: `lib/features/playback/practice_settings.dart`, `lib/features/playback/resolve_practice.dart`, `lib/features/playback/playback_cubit.dart`;
  - score and editor: `lib/features/score/score_cubit.dart`, `lib/features/editor/editor_cubit.dart`.
- Create: `lib/features/playback/practice_moves.dart`
- Test: `test/unit/engine/engine_bridge_test.dart`, `test/unit/features/playback/*`, `test/unit/features/score/score_cubit_test.dart`, `test/unit/features/editor/editor_cubit_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces (Dart):
  - `TrackMix.volume` (`int`);
  - `TrackSummary.volume` and `channel`;
  - `TrackPractice.volume` (`int?`, where null means the file's level);
  - commands `AddTrack(List<int> tuning, int program)`, `RemoveTrack(int track)`, `MoveTrack(int track, int to)` and `RenameTrack(int track, String name)`;
  - `EditState.drawnTrack`.
- Produces (practice): `Map<int, TrackPractice> movePractice(SongSummary before, SongSummary after, Map<int, TrackPractice> practice)`, in `practice_moves.dart`. It matches tracks by channel, in order. `PlaybackCubit` uses it when a same-`openId` song changes its tracks, then saves and sends the mix and staves.
- Produces (cubits):
  - `PlaybackCubit.setVolume(int track, int volume, {bool save = true})`;
  - `ScoreCubit.applyEdit(SongSummary song, {int? drawnTrack})` sets `selectedTrackIndex`;
  - `EditorCubit` methods `addTrack(List<int> tuning, int program)`, `removeTrack(int track)`, `moveTrack(int track, int to)` and `renameTrack(int track, String name)`, which need no cursor;
  - `EditorCubit` passes `drawnTrack` to `applyEdit`.

- [ ] **Step 1: Write the failing tests:**
  - **`movePractice`**, unit tests:
    - a move swaps the practices;
    - a removal drops one and shifts the rest;
    - an addition gets defaults;
    - repeated channels match in order.
  - **`practice follows its track through a move, a removal and an undo`**, in `playback_cubit_test.dart`: tone and volume on tracks 0 and 2, then song summaries in the moved, removed and restored orders through `ScoreCubit.applyEdit`, give each track its own practice, both saved and sent.
  - **`setVolume sends and saves, and a preview only sends`.**
  - **`the volume resolves to the file's level`**, in `resolve_practice_test.dart`.
  - **`applyEdit follows the drawn track`**, in `score_cubit_test.dart`.
  - **The editor cubit:** the track commands send without a cursor, and the reply's `drawnTrack` reaches `ScoreCubit`.
  - **The bridge:** each command serialises, and the summary and edit state parse `volume`, `channel` and `drawnTrack`.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test --timeout 60s && flutter analyze`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: tracks and volume in the cubits`

---

### Task 4: The drawer's mixer and track menu

**Files:**
- Modify: `lib/features/score/track_drawer.dart`, `lib/features/score/track_info_panel.dart`, `lib/features/editor/new_song_dialog.dart`, `lib/l10n/app_en.arb`
- Create:
  - `lib/features/editor/tuning_fields.dart`, holding the string-count, preset and custom-tuning fields taken out of `NewSongDialog`;
  - `lib/features/score/add_track_dialog.dart`.
- Test: `test/widget/score/track_drawer_test.dart`, `test/widget/score/track_info_panel_test.dart`, `test/widget/score/add_track_dialog_test.dart`, `test/widget/editor/new_song_dialog_test.dart`

**Interfaces:**
- Consumes: Task 3.
- Produces, in the drawer header beside the collapse button:
  - **Add track** (`Icons.add`): opens `AddTrackDialog` (strings, tuning and Add), then calls `editor.addTrack(tuning, defaultTone.program)`.
  - **Mixer** (`Icons.tune`, selected while on): swaps each row's bar grid for a `Slider` of 0–16 with 16 divisions and a percentage label. `onChanged` calls `setVolume(i, v, save: false)`, and `onChangeEnd` calls `setVolume(i, v)`. The on/off choice is kept in the drawer's state only.
- Produces, on each guitar row, a ⋮ menu (`Icons.more_vert`, tooltip "Track actions"):
  - Move up and Move down, disabled at the ends;
  - Remove track, disabled for the only guitar track. It asks first: "Remove "<name>"? Its notes are removed too." with Cancel and a red Remove.
- Produces, in the track information panel: the track name becomes a button with a pencil that opens a rename dialog (Save, Cancel).

- [ ] **Step 1: Write the failing tests:**
  - **The drawer:**
    - `the mixer swaps the grid for volume sliders`, at the file's level: 12 shows `75%`;
    - `dragging a slider previews, and letting go saves`;
    - `add track asks for the tuning and adds it`;
    - `the track menu moves and removes`, with the confirmation;
    - `the ends and the last guitar track disable their actions`;
    - `drum rows have no track menu`.
  - **The panel:** `the track name renames the track`.
  - **The New song dialog's tests still pass** after the refactor.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `npm --prefix engine run build && flutter test --timeout 60s && flutter analyze`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: the track drawer's mixer, add track and track menu`

---

### Task 5: Simulator acceptance

No new code unless a check fails. A failure goes through superpowers:systematic-debugging, and its fix needs a test that failed first.

- [ ] **Step 1: Build and install**

Run: `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted dev.edbrsk.duoscore`
Expected: build succeeds; the app launches.

- [ ] **Step 2: Owner checks**, reported back in one message:
  1. Mixer on: every track has a slider at its file level. Lowering one while playing makes it quieter at once, and the level survives a tone change and reopening the song.
  2. Add a 7-string track in Drop A. It appears last, is drawn, and you can write in it.
  3. Move it up and down. The drawer, the drawn track and each track's tone and volume follow.
  4. Rename it in the track panel.
  5. Remove it after the confirmation, and undo brings it back with its notes.
  6. The "(DuoScore)" copy opens in Guitar Pro 8 with the new track, the order, the names and the volumes.

- [ ] **Step 3: Record the results** in the ledger, one line per check, and fix any failure as described above.
