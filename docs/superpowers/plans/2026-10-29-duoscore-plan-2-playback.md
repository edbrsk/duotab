# DuoScore Plan 2: Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play the open song from a transport under the score, with per-file practice settings (tone, mute/solo, speed, A–B loop), count-in and metronome, a Guitar Pro-style track drawer with a bar overview grid, a track information panel, a licence screen, and pause when the phone closes.

**Architecture:** The engine (`engine/`) gains player commands and pushes player events (state, current bar, loop range) over the existing bridge. Dart gets a `PlaybackCubit` that follows `ScoreCubit`'s open song, resolves and persists its practice settings in Application Support (never in the song file), and sends them to the engine. Song files are never written. The track drawer and the track information panel read `ScoreCubit` and `PlaybackCubit`; the drawer replaces Plan 1's right-hand track list.

**Tech Stack:** as Plan 1, plus `webview_flutter_wkwebview` (direct dependency for the WebKit creation params). alphaTab 1.6.1 APIs used: `play`/`pause`/`stop`, `playerReady`, `playerStateChanged`, `playerPositionChanged`, `playbackRangeChanged`, `tickPosition`, `playbackSpeed`, `isLooping`, `playbackRange`, `countInVolume`, `metronomeVolume`, `changeTrackMute`/`changeTrackSolo`, `loadMidiForScore`, `midiLoaded`, `tickCache` (`masterBars`, `getMasterBarStart`), `renderer.boundsLookup.getBeatAtPos`, `scrollToCursor`, and headless `midi.MidiFileGenerator` for the bar timeline.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md` (sections Playback, Track drawer, Screen layout, iPhone Duo behaviour, Constraints › Licences)

**Left for Plan 3:** the single-note preview for editing, and writing each guitar track's tone into a saved song; both need the editor.

**Branch:** `plan-2-playback`, created from `plan-1-foundation` (Plan 1's PR is not merged yet; rebase onto `main` once it is).

## Global Constraints

Plan 1's Global Constraints all still apply (iOS 27.1 only, channel names, verbatim `analysis_options.yaml` with `flutter analyze` clean at every commit, no (L)GPL Dart packages, alphaTab pinned to exactly `1.6.1` and shipped unmodified, engine built into git-ignored `assets/engine/`, protocol declared in `engine/src/protocol.ts` and mirrored in `lib/engine/protocol.dart` in the same commit, every user-facing string from `lib/l10n/app_en.arb`, private songs only via `DUOSCORE_PRIVATE_SAMPLE`). In addition:

- Tones are General MIDI programs, stored 0-based as alphaTab does: Clean = 27 (GM 28 Electric Guitar (clean)), Overdrive = 29 (GM 30 Overdriven Guitar), High gain = 30 (GM 31 Distortion Guitar). Exact labels: `Clean`, `Overdrive`, `High gain`.
- A guitar track starts with its file's program when that is one of the three tones, otherwise with the default tone from Settings (`Clean` until the owner changes it).
- Speed is 25–150% of the written tempo, in 5% steps, with 50/75/100% shortcuts.
- Practice settings (tone, mute, solo, speed, loop) are kept per file, keyed by the path relative to Documents, in `<Application Support>/practice.json`. App settings (count-in, metronome, default tone) live in `<Application Support>/settings.json`. Nothing in this plan writes to Documents.
- The track drawer lists every track (drums and bass included), up to 40% of the screen height, then scrolls.
- Licences shown in Settings: alphaTab (MPL-2.0, with a link to https://github.com/CoderLine/alphaTab), Bravura (SIL OFL 1.1), Sonivox SoundFont (Apache-2.0), each with its full licence text from the files the engine build already copies.

## Review Focus

1. **A missing, corrupt or out-of-date practice file** (JSON garbage, or a song whose file now has fewer tracks than the stored settings name) must open the song with defaults or the valid part of the settings, never fail the open. Tests: Task 3 `a corrupt file reads as empty`, Task 4 `resolvePractice ignores tracks the song no longer has`.
2. **The phone closing during playback** must pause; reopening must not resume on its own. Test: Task 1 `pauses when the hinge closes`.
3. **The engine page restarting** (iOS killed the web process) must stop showing playback, then reapply the song's practice settings and the count-in/metronome options once the song reopens. Tests: Task 1 `an engine restart stops showing playback`, Task 4 `reapplies practice after the engine reopens the song`, Task 6 `resends player options after the engine restarts`.
4. **Changing a tone during playback** regenerates the MIDI; position, playing state, mute, solo and the loop must survive it. Test: Task 4 `a program change keeps position, mixer and loop`.
5. **A finger swipe on the score** must scroll, not start a loop selection; only a press held still for the long-press delay selects. Test: Task 5 `a swipe before the delay selects nothing`.

---

### Task 1: Play, pause and stop from the transport

**Files:**
- Modify: `engine/src/protocol.ts`, `engine/src/main.ts`, `lib/engine/engine_bridge.dart`, `lib/engine/engine_host.dart`, `pubspec.yaml`, `lib/l10n/app_en.arb`, `lib/features/score/score_page.dart`, `lib/core/dependency_injection.dart`, `lib/main.dart`
- Create: `lib/features/playback/playback_cubit.dart`, `lib/features/playback/transport_bar.dart`
- Test: `test/unit/engine/engine_bridge_test.dart`, `test/unit/features/playback/playback_cubit_test.dart`, `test/widget/playback/transport_bar_test.dart`

**Interfaces:**
- Produces (protocol): requests `play`, `pause`, `stop` (payload `{}`, reply `{}`); event `playerState` with payload `{ playing: boolean }`.
- Produces (Dart): `EngineBridge.play()`, `.pause()`, `.stop()` → `Future<void>`. `class PlaybackState { final bool playing; }` (later tasks add fields). `class PlaybackCubit extends Cubit<PlaybackState>` with `PlaybackCubit({required EngineBridge engine, required HingeStatusProvider hinge})`, `Future<void> playPause()`, `Future<void> pause()`, `Future<void> stop()`. `class TransportBar extends StatelessWidget` (reads `PlaybackCubit` from context).

- [ ] **Step 1: Write the failing bridge test** in `engine_bridge_test.dart`:

```dart
test('play, pause and stop send their requests', () async {
  transport.deliver({'event': 'ready', 'payload': {}});
  for (final (call, type) in [
    (bridge.play, 'play'),
    (bridge.pause, 'pause'),
    (bridge.stop, 'stop'),
  ]) {
    final done = call();
    await pumpEventQueue();
    expect(transport.lastRequest['type'], type);
    transport.deliver({'id': transport.lastRequest['id'], 'ok': true, 'payload': {}});
    await done;
  }
});
```

- [ ] **Step 2: Write the failing cubit tests** in `playback_cubit_test.dart`, using a mocktail `EngineBridge` with a broadcast `events` controller (as `score_cubit_test.dart` does) and `HingeStatusProvider(hingeEvents: hingeController.stream)`:
  - `follows the engine's player state`: events `playerState {playing: true}` then `{playing: false}` → states `playing` true, then false.
  - `playPause plays when paused and pauses when playing`: from initial state, `playPause()` verifies `engine.play()`; after a `playerState {playing: true}` event, `playPause()` verifies `engine.pause()`.
  - `pauses when the hinge closes`: after `playerState {playing: true}`, hinge emits `'closed'` → `engine.pause()` called once; hinge emits `'fullyOpen'` → `engine.play()` never called.
  - `an engine restart stops showing playback`: after `playerState {playing: true}`, a `ready` event → state `playing` false.

- [ ] **Step 3: Write the failing widget tests** in `transport_bar_test.dart` with a `MockCubit<PlaybackState>` (`bloc_test`) as `PlaybackCubit`:
  - `shows play, then pause while playing`: state `playing: false` → `find.byTooltip('Play')`; state `playing: true` → `find.byTooltip('Pause')`.
  - `buttons call the cubit`: tapping Play calls `playPause()`; tapping Stop calls `stop()`.

- [ ] **Step 4: Run them to verify they fail**

Run: `flutter test test/unit/engine/engine_bridge_test.dart test/unit/features/playback test/widget/playback`
Expected: FAIL to compile: `play` isn't defined for `EngineBridge`; `playback_cubit.dart` not found.

- [ ] **Step 5: Implement the engine side.** In `protocol.ts` add `'play' | 'pause' | 'stop'` to `RequestType`, `'playerState'` to `EventType`, and `export type PlayerStatePayload = { playing: boolean }`. In `main.ts`: a `whenPlayerReady(): Promise<void>` that resolves at once when `api.isReadyForPlayback`, otherwise on the next `api.playerReady`; `play` awaits it and then calls `api.play()`; `pause` → `api.pause()`; `stop` → `api.stop()`. Post `playerState` from `api.playerStateChanged` with `playing: e.state === alphaTab.synth.PlayerState.Playing`.

- [ ] **Step 6: Implement the Dart side.**
  - `EngineBridge.play/pause/stop` are `_request` calls with an empty payload.
  - `PlaybackCubit` listens to `engine.events`: `playerState` sets `playing`; `ready` sets `playing: false`. It also listens to `hinge` and calls `pause()` when `!hinge.isOpen`. `playPause()` calls `pause()` when `state.playing`, else `engine.play()`. Engine failures are caught and `debugPrint`ed, and the state stays as the engine reports it.
  - `TransportBar`: a `Row` on `AppColors.panel` with `IconButton`s Stop (`Icons.stop`) and Play/Pause (`Icons.play_arrow` / `Icons.pause`), tooltips from l10n keys `play` ("Play"), `pause` ("Pause"), `stop` ("Stop").
  - `EngineHost` builds its controller with `WebViewController.fromPlatformCreationParams(WebKitWebViewControllerCreationParams(mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{}, allowsInlineMediaPlayback: true))`, so audio can start from a Flutter button rather than a touch inside the page; add `webview_flutter_wkwebview: ^3.27.2` to `pubspec.yaml` dependencies (sorted).
  - `ScorePage` passes `transport: const TransportBar()` to `WorkspaceLayout`. `setupDependencies` creates `HingeStatusProvider` before `PlaybackCubit` and registers `PlaybackCubit(engine: engine, hinge: hinge)`; `main.dart` adds `BlocProvider.value(value: getIt<PlaybackCubit>())`. Existing widget tests that pump `ScorePage` provide a `MockCubit<PlaybackState>` too.

- [ ] **Step 7: Run the tests and the suites**

Run: `flutter test && npm --prefix engine test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add -A engine/src lib test pubspec.yaml pubspec.lock
git commit -m "feat: play, pause and stop from the transport"
```

---

### Task 2: Bar timeline, current bar and seeking

**Files:**
- Create: `engine/src/timeline.ts`, `engine/test/timeline.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/src/summary.ts`, `engine/src/main.ts`, `engine/test/fixtures.ts`, `lib/engine/protocol.dart`, `lib/engine/engine_bridge.dart`, `lib/features/playback/playback_cubit.dart`
- Test: `test/unit/engine/protocol_test.dart`, `test/unit/features/playback/playback_cubit_test.dart`

**Interfaces:**
- Consumes: Task 1's `PlaybackCubit`, `PlaybackState`.
- Produces (protocol): `type Section = { marker: string; text: string }`; `type BarInfo = { index: number; startTick: number; startMs: number; tempo: number; section: Section | null }` (first time the bar plays, counting repeats); `SongSummary` gains `bars: BarInfo[]` and `TrackSummary` gains `barsWithNotes: boolean[]`, both filled by `open` and empty from `summarize`. Request `seekBar` with `{ bar: number }`. Event `position` with `{ bar: number }`, posted only when the bar under the playback position changes, and after every seek.
- Produces (engine): `barTimeline(score: Score): BarInfo[]`, `barsWithNotes(track: Track): boolean[]`, `barAtTick(lookups: { start: number; end: number; masterBar: { index: number } }[], tick: number): number`.
- Produces (Dart): `class Section { final String marker; final String text; }`, `class BarInfo { final int index; final int startTick; final int startMs; final double tempo; final Section? section; }`, `SongSummary.bars` (`List<BarInfo>`, default `const []`), `TrackSummary.barsWithNotes` (`List<bool>`, default `const []`). `EngineBridge.seekBar(int bar)`. `PlaybackState.bar` (`int`, default 0). `PlaybackCubit` gains `required ScoreCubit score` and `Future<void> seekBar(int bar)`.

- [ ] **Step 1: Add the timeline fixtures** to `engine/test/fixtures.ts`:

```ts
export const tempoAndSections = String.raw`\title "Timeline"
\tempo 120
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
\section "A" "Intro" 0.6.4*4 | \tempo 60 0.6.4*4 | \section "B" "Verse" r.1 | 3.5.1`;

export const repeated = String.raw`\title "Repeat"
\tempo 120
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
\ro 0.6.4*4 | \rc 2 2.6.4*4 | 3.5.1`;
```

and a `score(alphaTex: string): Score` helper next to `gpBytes` (the same `AlphaTexImporter` steps, returning `readScore()`).

- [ ] **Step 2: Write the failing engine tests** in `timeline.test.ts`:

```ts
test('barTimeline gives start, tempo and section per bar', () => {
  expect(barTimeline(score(tempoAndSections))).toEqual([
    { index: 0, startTick: 0, startMs: 0, tempo: 120, section: { marker: 'A', text: 'Intro' } },
    { index: 1, startTick: 3840, startMs: 2000, tempo: 60, section: null },
    { index: 2, startTick: 7680, startMs: 6000, tempo: 60, section: { marker: 'B', text: 'Verse' } },
    { index: 3, startTick: 11520, startMs: 10000, tempo: 60, section: null },
  ]);
});

test('barTimeline uses the first pass through a repeat', () => {
  expect(barTimeline(score(repeated)).map((b) => [b.startTick, b.startMs])).toEqual([
    [0, 0], [3840, 2000], [15360, 8000],
  ]);
});

test('barsWithNotes is false for rest-only bars', () => {
  expect(barsWithNotes(score(tempoAndSections).tracks[0])).toEqual([true, true, false, true]);
});

test('barAtTick finds the bar being played, repeats included', () => {
  const lookups = [0, 1, 0, 1, 2].map((index, i) => ({ start: i * 3840, end: (i + 1) * 3840, masterBar: { index } }));
  expect(barAtTick(lookups, 0)).toBe(0);
  expect(barAtTick(lookups, 9000)).toBe(0);
  expect(barAtTick(lookups, 12000)).toBe(1);
  expect(barAtTick(lookups, 99999)).toBe(2);
});
```

- [ ] **Step 3: Write the failing Dart tests.**
  - `protocol_test.dart`, `parses bars and bars with notes`: a `SongSummary.fromJson` with one bar `{index: 0, startTick: 0, startMs: 0, tempo: 120, section: {marker: 'A', text: 'Intro'}}` and a track with `barsWithNotes: [true]` → `song.bars.single.section!.marker == 'A'`, `song.tracks.single.barsWithNotes == [true]`; and the existing library-shaped JSON without these keys still parses, to empty lists.
  - `playback_cubit_test.dart`, `follows the current bar`: event `position {bar: 7}` → `state.bar == 7`.
  - `seekBar asks the engine to seek`: `seekBar(3)` verifies `engine.seekBar(3)`.
  - `opening another song goes back to bar 0 and paused`: with `bar: 7, playing: true`, the `ScoreCubit` stream emitting a state with a new `song` → `bar: 0, playing: false`. Build the `ScoreCubit` in the test with the same mocked engine.

- [ ] **Step 4: Run them to verify they fail**

Run: `npm --prefix engine test; flutter test test/unit/engine/protocol_test.dart test/unit/features/playback`
Expected: FAIL: `timeline` module missing; `bars` not defined on `SongSummary`; `seekBar` not defined.

- [ ] **Step 5: Implement `timeline.ts`.** `barTimeline` runs `new midi.MidiFileGenerator(score, new Settings(), new midi.AlphaSynthMidiFileHandler(new midi.MidiFile())).generate()`, walks `generator.tickLookup.masterBars` in playback order, and keeps the first lookup per `masterBar.index`. It converts ticks to milliseconds by summing each lookup's `tempoChanges` segments at 960 ticks per quarter note. `tempo` is the tempo in effect at the bar's start. A bar the MIDI never reaches falls back to `masterBar.start` and the last known tempo. `barsWithNotes` maps `track.staves[0].bars` to `!bar.isRestOnly`. `barAtTick` returns the `masterBar.index` of the last lookup whose `start <= tick`.

- [ ] **Step 6: Wire the engine.** `summary.ts` exports `describeOpened(score, fileName): SongSummary`, which is `summarizeScore` plus `bars` and per-track `barsWithNotes`; `open` returns it, and `summarize` keeps returning empty arrays for both. `main.ts`: `seekBar` awaits `whenPlayerReady()`, sets `api.tickPosition = api.tickCache!.getMasterBarStart(api.score!.masterBars[bar])`, calls `api.scrollToCursor()` and posts `position`. `api.playerPositionChanged` computes `barAtTick(api.tickCache.masterBars, e.currentTick)` and posts `position` when it differs from the last posted bar; `open` resets the last posted bar.

- [ ] **Step 7: Implement the Dart side**: `Section`, `BarInfo` and the two new fields in `protocol.dart` (`fromJson` reads missing keys as empty lists); `EngineBridge.seekBar`; `PlaybackCubit` handles `position`, adds `seekBar`, and subscribes to `score.stream`: a state whose `song` is not `identical` to the last one it saw resets `bar` to 0 and `playing` to false. Update DI to pass `score`.

- [ ] **Step 8: Run the tests and the suites**

Run: `npm --prefix engine test && flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add -A engine lib test
git commit -m "feat: bar timeline, current bar and seeking"
```

---

### Task 3: Settings and practice storage

**Files:**
- Create: `lib/core/storage/json_file.dart`, `lib/features/playback/tone.dart`, `lib/features/playback/practice_settings.dart`, `lib/features/playback/practice_store.dart`, `lib/features/settings/settings_cubit.dart`
- Modify: `lib/core/dependency_injection.dart`, `lib/main.dart`
- Test: `test/unit/core/storage/json_file_test.dart`, `test/unit/features/playback/practice_store_test.dart`, `test/unit/features/settings/settings_cubit_test.dart`

**Interfaces:**
- Produces:
  - `class JsonFile { JsonFile(File file); Future<Map<String, dynamic>> read(); Future<void> write(Map<String, dynamic> data); }`. A missing or unreadable file reads as `{}`. Writes are atomic (temp file in the same folder, then rename) and run one at a time in call order.
  - `enum Tone { clean(27), overdrive(29), highGain(30); const Tone(this.program); final int program; static Tone? fromProgram(int program); }`
  - `class TrackPractice { final bool mute; final bool solo; final Tone? tone; }` (tone null for non-guitar tracks); `class PlaybackRange { final int startTick; final int endTick; }` (in `lib/engine/protocol.dart`, since the engine sends it); `class PracticeSettings { final double speed; final bool looping; final PlaybackRange? range; final Map<int, TrackPractice> tracks; }` with defaults `speed 1.0`, `looping false`, `range null`, `tracks {}`, plus `copyWith`, `toJson` and `fromJson`.
  - `class PracticeStore { PracticeStore(JsonFile file); Future<PracticeSettings?> load(String path); Future<void> save(String path, PracticeSettings settings); }`
  - `class AppSettings { final bool countIn; final bool metronome; final Tone defaultTone; }`, defaults `false`, `false`, `Tone.clean`; `class SettingsCubit extends Cubit<AppSettings> { SettingsCubit(JsonFile file); Future<void> load(); Future<void> setCountIn(bool on); Future<void> setMetronome(bool on); Future<void> setDefaultTone(Tone tone); }`. Each setter emits, then writes.

- [ ] **Step 1: Write the failing tests** (temp directories from `Directory.systemTemp.createTemp`):
  - `json_file_test.dart`: `a missing file reads as empty`; `a corrupt file reads as empty` (file content `{not json`); `writes and reads back` (`{'a': 1}`); `concurrent writes land in call order` (`write({'n': 1})` and `write({'n': 2})` without awaiting the first, then `read()` → `{'n': 2}`).
  - `practice_store_test.dart`: `round-trips practice settings` (speed 0.75, looping true, range 960–3840, track 1 `mute: true, solo: false, tone: Tone.highGain`, track 2 with tone null), saved under `'songs/a.gp'` and loaded back equal field by field; `an unknown path loads null`; `keeps other songs when saving one`.
  - `settings_cubit_test.dart`: `loads defaults when nothing is stored`; `persists each setting` (set all three, then a fresh `SettingsCubit` on the same file `load()`s `countIn true, metronome true, defaultTone overdrive`).
  - `Tone.fromProgram`: `27 → clean, 29 → overdrive, 30 → highGain, 24 → null` (in `practice_store_test.dart`'s group `Tone`).

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/unit/core/storage test/unit/features/playback/practice_store_test.dart test/unit/features/settings`
Expected: FAIL to compile: files not found.

- [ ] **Step 3: Implement** the files above. In `PracticeSettings.toJson`, track keys are the track index as a string and tones are stored by `Tone.name`; an unknown tone name reads as null.

- [ ] **Step 4: Wire it**: `setupDependencies` resolves `getApplicationSupportDirectory()`, creates it if needed, builds `JsonFile`s for `practice.json` and `settings.json`, awaits `SettingsCubit.load()`, and registers `PracticeStore` and `SettingsCubit`; `main.dart` adds `BlocProvider.value(value: getIt<SettingsCubit>())`.

- [ ] **Step 5: Run the tests and the suite**

Run: `flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "feat: store app settings and per-song practice settings"
```

---

### Task 4: Mute, solo and tones

**Files:**
- Create: `engine/src/mixer.ts`, `engine/test/mixer.test.ts`, `lib/features/playback/resolve_practice.dart`
- Modify: `engine/src/protocol.ts`, `engine/src/main.ts`, `lib/engine/protocol.dart`, `lib/engine/engine_bridge.dart`, `lib/features/playback/playback_cubit.dart`, `lib/core/dependency_injection.dart`
- Test: `test/unit/features/playback/resolve_practice_test.dart`, `test/unit/features/playback/playback_cubit_test.dart`

**Interfaces:**
- Consumes: Task 3's `PracticeStore`, `PracticeSettings`, `TrackPractice`, `Tone`, `SettingsCubit`; Task 2's `PlaybackCubit` song tracking.
- Produces (protocol): `type TrackMix = { index: number; mute: boolean; solo: boolean; program: number }`; request `setTracks` with `{ tracks: TrackMix[] }`.
- Produces (engine): `class Mixer { constructor(api: MixerApi); apply(mixes: TrackMix[]): Promise<void> }`, where `MixerApi` is the subset of `AlphaTabApi` it uses: `score`, `tickPosition`, `playerState`, `isLooping`, `playbackRange`, `play()`, `pause()`, `loadMidiForScore()`, `changeTrackMute()`, `changeTrackSolo()`, `midiLoaded.on()`.
- Produces (Dart): `class TrackMix { final int index; final bool mute; final bool solo; final int program; Map<String, Object> toJson(); }` in `lib/engine/protocol.dart`; `EngineBridge.setTracks(List<TrackMix> tracks)`; `PracticeSettings resolvePractice(SongSummary song, PracticeSettings? saved, Tone defaultTone)`; `PlaybackState.practice` (`PracticeSettings`); `PlaybackCubit` gains `required PracticeStore practice`, `required SettingsCubit settings`, `Future<void> setMute(int track, bool on)`, `Future<void> setSolo(int track, bool on)`, `Future<void> setTone(int track, Tone tone)`.

- [ ] **Step 1: Write the failing engine tests** in `mixer.test.ts`, against a fake `MixerApi` that records calls, holds `tickPosition`, and fires `midiLoaded` handlers when `loadMidiForScore()` is called (then resets `tickPosition` to 0, as alphaTab does):
  - `mutes and solos without regenerating MIDI when programs are unchanged`: `apply([{index: 0, mute: true, solo: false, program: 29}])` on a track already at 29 → `changeTrackMute([track0], true)`, `changeTrackSolo([track0], false)`, no `loadMidiForScore`.
  - `a program change keeps position, mixer and loop`: playing, `tickPosition 5000`, loop range 960–3840, track 1 muted by an earlier `apply`; `apply([{index: 0, …, program: 30}])` → `score.tracks[0].playbackInfo.program === 30`, one `loadMidiForScore`, afterwards `tickPosition === 5000`, `playbackRange` and `isLooping` as before, track 1's mute re-sent after the reload, `play()` called once.

- [ ] **Step 2: Write the failing Dart tests.**
  - `resolve_practice_test.dart`:
    - `guitar tracks keep a file program that is a tone`: track program 29, nothing saved → tone `overdrive`.
    - `other guitar programs start with the default tone`: program 25, default `highGain` → `highGain`.
    - `saved settings win`: saved track 1 `tone clean, mute true` → those.
    - `non-guitar tracks have no tone`: drums → tone null.
    - `resolvePractice ignores tracks the song no longer has`: saved track 9 on a 3-track song → no key 9, the rest resolved.
  - `playback_cubit_test.dart` (temp-dir `PracticeStore`, `SettingsCubit` on a temp `JsonFile`):
    - `opening a song sends its resolved mix`: `drumsAndTwoGuitars` (program 29) → `engine.setTracks` with three mixes, guitars at program 29, drums at their file program, none muted.
    - `setMute updates, persists and sends`: `setMute(1, true)` → `state.practice.tracks[1]!.mute`, `PracticeStore.load('fixture.gp')` has it, `setTracks` sent with track 1 muted.
    - `setTone sends the tone's program`: `setTone(2, Tone.highGain)` → `setTracks` with track 2 at program 30.
    - `reapplies practice after the engine reopens the song`: after `setMute(1, true)`, a `ready` event and `ScoreCubit` emitting a new song object for the same path → `setTracks` sent again with track 1 muted.

- [ ] **Step 3: Run them to verify they fail**

Run: `npm --prefix engine test; flutter test test/unit/features/playback`
Expected: FAIL: `mixer` module missing; `resolvePractice` and `setTracks` not defined.

- [ ] **Step 4: Implement `Mixer`.** It remembers the latest mix per track. `apply` writes each mix's `program` into `score.tracks[index].playbackInfo.program`. If any program changed, it records the tick, playing state, `playbackRange` and `isLooping`, pauses, calls `loadMidiForScore()` and awaits the next `midiLoaded`. It then restores those four (resuming with `play()` if it was playing) and re-sends mute and solo for every remembered track. In all cases it sends `changeTrackMute`/`changeTrackSolo` for the given mixes. Unknown indexes throw `no track <n>`. `main.ts` handles `setTracks` with a `Mixer` it creates once, and clears the mixer's memory in `open`.

- [ ] **Step 5: Implement the Dart side.** `resolvePractice` keeps `speed`, `looping` and `range` from `saved`, and resolves one `TrackPractice` per song track by the rules in Global Constraints. On each new song (Task 2's identity check), `PlaybackCubit` loads `practice.load(path)`, resolves it with `settings.state.defaultTone`, emits it and sends `setTracks` (program = `tone?.program ?? track.midiProgram`). `setMute`, `setSolo` and `setTone` each update `state.practice`, save it under the song's path and send `setTracks` with that one track. Update DI.

- [ ] **Step 6: Run the tests and the suites**

Run: `npm --prefix engine test && flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add -A engine lib test
git commit -m "feat: per-track mute, solo and tone, kept per song"
```

---

### Task 5: Speed and A–B loop

**Files:**
- Create: `engine/src/touch_selection.ts`, `engine/test/touch_selection.test.ts`, `lib/features/playback/speed_control.dart`
- Modify: `engine/src/protocol.ts`, `engine/src/main.ts`, `engine/index.html`, `lib/engine/protocol.dart`, `lib/engine/engine_bridge.dart`, `lib/features/playback/playback_cubit.dart`, `lib/features/playback/transport_bar.dart`, `lib/l10n/app_en.arb`
- Test: `test/unit/features/playback/playback_cubit_test.dart`, `test/widget/playback/transport_bar_test.dart`

**Interfaces:**
- Consumes: Task 4's practice flow (`state.practice`, save on change), Task 2's `BarInfo.tempo` and `PlaybackState.bar`.
- Produces (protocol): requests `setSpeed` with `{ speed: number }` (0.25–1.5), `setLooping` with `{ looping: boolean }`, `setRange` with `{ range: { startTick: number; endTick: number } | null }`; event `rangeChanged` with `{ range: … | null }`, from alphaTab's `playbackRangeChanged`.
- Produces (engine): `class LongPressSelection { constructor(deps: { beatAt(x: number, y: number): Beat | null; select(start: Beat, end: Beat): void; delayMs?: number /* 400 */; slopPx?: number /* 10 */ }); touchStart(e: TouchEvent): void; touchMove(e: TouchEvent): void; touchEnd(e: TouchEvent): void; }`.
- Produces (Dart): `EngineBridge.setSpeed(double)`, `.setLooping(bool)`, `.setRange(PlaybackRange?)`; `PlaybackCubit.setSpeed(double speed)`, `.setLooping(bool on)`; `class SpeedControl extends StatelessWidget`.

- [ ] **Step 1: Write the failing engine tests** in `touch_selection.test.ts`, with `vi.useFakeTimers()` and minimal fake `TouchEvent`s (`touches[0].clientX/Y`, `preventDefault` spy). `beatAt` maps an x to beat objects `b0`, `b1` and `b2`, one every 100 px.
  - `a long press then a drag selects from the pressed beat`: start at x 50, advance 400 ms, move to x 250 → `select(b0, b2)`, and `preventDefault` was called on the move and the end.
  - `a swipe before the delay selects nothing`: start at x 50, move to x 80 after 100 ms, advance 1000 ms → `select` never called, `preventDefault` never called.
  - `a long press without moving selects one beat`: start at x 150, advance 400 ms, end → `select(b1, b1)`.
  - `dragging backwards keeps the earlier beat first`: start at x 250, hold, move to x 50 → `select(b0, b2)`.

- [ ] **Step 2: Write the failing Dart tests.**
  - `playback_cubit_test.dart`:
    - `setSpeed clamps, persists and sends`: `setSpeed(2.0)` → `practice.speed == 1.5`, `engine.setSpeed(1.5)`, saved.
    - `a range from the engine is kept and saved`: event `rangeChanged {range: {startTick: 960, endTick: 3840}}` → `state.practice.range` 960–3840, saved; event with `range: null` clears it.
    - `opening a song sends speed, looping and range`: saved `speed 0.5, looping true, range 0–1920` → `setSpeed(0.5)`, `setLooping(true)`, `setRange(…)` after the song opens.
  - `transport_bar_test.dart` (from here on `TransportBar` also reads `ScoreCubit` for the song's bars, so the tests provide a `MockCubit<ScoreState>`):
    - `shows the current bar's tempo at the chosen speed`: a song whose bar 2 has tempo 120, `bar: 2`, speed 0.75 → text `♩ = 90`.
    - `speed shortcuts set 50, 75 and 100 percent`: open the speed menu, tap `50%`, `75%`, `100%` → `setSpeed(0.5)`, `setSpeed(0.75)`, `setSpeed(1.0)`.
    - `loop toggle sets looping`: tapping the Loop button with `looping: false` → `setLooping(true)`.

- [ ] **Step 3: Run them to verify they fail**

Run: `npm --prefix engine test; flutter test test/unit/features/playback test/widget/playback`
Expected: FAIL: `touch_selection` missing; `setSpeed` not defined.

- [ ] **Step 4: Implement `LongPressSelection`.** `touchStart` with one finger stores the point and starts the delay timer; a second finger cancels. A move farther than `slopPx` before the timer fires cancels (the page scrolls as usual). When the timer fires, it takes `beatAt` at the stored point; null cancels. While selecting, each move calls `preventDefault()` and `select(start, current)`, ordered by `absolutePlaybackStart`. `touchEnd` while selecting calls `preventDefault()`, so that no synthesized click clears the range, and selects once more.

- [ ] **Step 5: Wire the engine.**
  - `main.ts` attaches `LongPressSelection` to `#score` (`touchmove` with `{ passive: false }`). `beatAt` converts client coordinates to `#score`-relative ones and calls `api.renderer.boundsLookup?.getBeatAtPos`. `select` sets `api.playbackRange` the way alphaTab's own mouse selection does: start = `tickCache.getMasterBarStart(start.voice.bar.masterBar) + start.playbackStart`; end = the same for `end` + `end.playbackDuration − 50`. It then moves `tickPosition` to the start.
  - Requests: `setSpeed` → `api.playbackSpeed`; `setLooping` → `api.isLooping`; `setRange` → `api.playbackRange` (null clears). `api.playbackRangeChanged` posts `rangeChanged`. `open` resets speed to 1, looping off and range null before loading.
  - `index.html` adds `#score { -webkit-user-select: none; -webkit-touch-callout: none; }`, so a long press doesn't open the iOS text callout.

- [ ] **Step 6: Implement the Dart side.** `PlaybackCubit.setSpeed` clamps to 0.25–1.5 and rounds to 0.05; `setLooping` sets it; both persist and send. `rangeChanged` events update and persist the range. On a new song, `speed`, `looping` and `range` are sent after `setTracks`. `TransportBar` adds:
  - the tempo text `♩ = {bpm}` (l10n `tempoMarking`, `bpm` an int): `song.bars[state.bar].tempo × speed`, rounded, hidden when `bars` is empty;
  - `SpeedControl`: a `MenuAnchor` button labelled with the speed in percent, whose menu has `50%`, `75%` and `100%` items and a `Slider` from 25 to 150 in 5% steps;
  - a Loop toggle `IconButton` (`Icons.repeat`, tooltip l10n `loop` "Loop", selected while looping).

- [ ] **Step 7: Run the tests and the suites**

Run: `npm --prefix engine test && flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add -A engine lib test
git commit -m "feat: playback speed and A-B loop by long-press and drag"
```

---

### Task 6: Settings screen: count-in, metronome, default tone, licences

**Files:**
- Create: `lib/features/settings/licences.dart`
- Modify: `engine/src/protocol.ts`, `engine/src/main.ts`, `lib/engine/engine_bridge.dart`, `lib/features/playback/playback_cubit.dart`, `lib/features/settings/settings_page.dart`, `lib/main.dart`, `lib/l10n/app_en.arb`
- Test: `test/unit/features/playback/playback_cubit_test.dart`, `test/unit/features/settings/licences_test.dart`, `test/widget/settings/settings_page_test.dart`

**Interfaces:**
- Consumes: Task 3's `SettingsCubit`, `AppSettings`, `Tone`.
- Produces (protocol): request `setPlayerOptions` with `{ countIn: boolean; metronome: boolean }`.
- Produces (Dart): `EngineBridge.setPlayerOptions({required bool countIn, required bool metronome})`; `void registerBundledLicences(AssetBundle bundle)` (adds to `LicenseRegistry`); `SettingsPage` (reads `SettingsCubit`).

- [ ] **Step 1: Write the failing tests.**
  - `playback_cubit_test.dart`: `sends player options on start and on change`: building the cubit sends `setPlayerOptions(countIn: false, metronome: false)`; `settings.setCountIn(true)` sends `(true, false)`. `resends player options after the engine restarts`: a `ready` event sends them again.
  - `licences_test.dart`: `registers alphaTab, Bravura and Sonivox`: with a fake `AssetBundle` that returns `'MPL TEXT'`, `'OFL TEXT'` and `'APACHE TEXT'` for `assets/engine/alphatab/LICENSE`, `assets/engine/alphatab/font/Bravura-OFL.txt` and `assets/engine/alphatab/soundfont/LICENSE`, the collected `LicenseRegistry.licenses` have packages `alphaTab`, `Bravura` and `Sonivox SoundFont`. alphaTab's paragraphs include `https://github.com/CoderLine/alphaTab` and `MPL TEXT`.
  - `settings_page_test.dart`:
    - `toggles count-in and metronome`: tapping the `Count-in` and `Metronome` switches calls `setCountIn(true)` and `setMetronome(true)` on a `MockCubit<AppSettings>`.
    - `chooses the default tone`: tapping `High gain` calls `setDefaultTone(Tone.highGain)`.
    - `opens the licence screen`: tapping `Licences` shows `LicensePage`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/unit/features/playback test/unit/features/settings test/widget/settings`
Expected: FAIL: `setPlayerOptions`, `registerBundledLicences` not defined; no `Count-in` switch.

- [ ] **Step 3: Implement.**
  - Engine `setPlayerOptions` sets `api.countInVolume` and `api.metronomeVolume` to 1 or 0.
  - `PlaybackCubit` sends the options at construction, on every `settings.stream` change and after each `ready` event.
  - `registerBundledLicences` adds one `LicenseEntryWithLineBreaks` per package, loading each text through `bundle.loadString`; alphaTab's entry starts with "Shipped unmodified. Source: https://github.com/CoderLine/alphaTab". `main.dart` calls it with `rootBundle` before `runApp`.
  - `SettingsPage`: a `ListView` with `SwitchListTile`s `Count-in` and `Metronome`, a `Default tone` group (`RadioGroup<Tone>` with three `RadioListTile`s, labelled `Clean`, `Overdrive` and `High gain`) and a `Licences` `ListTile` that calls `showLicensePage(context: context, applicationName: 'DuoScore')`. It sits in a transparent `Material` with a `SafeArea`, as `LibraryPage` does. New l10n keys: `countIn`, `metronome`, `defaultTone`, `toneClean`, `toneOverdrive`, `toneHighGain`, `licences`.

- [ ] **Step 4: Run the tests and the suite**

Run: `flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A engine/src lib test
git commit -m "feat: settings for count-in, metronome, default tone and licences"
```

---

### Task 7: Track drawer

**Files:**
- Create: `lib/features/score/track_drawer.dart`
- Modify: `lib/presentation/workspace/workspace_layout.dart`, `lib/features/score/score_page.dart`, `lib/l10n/app_en.arb`
- Test: `test/widget/score/track_drawer_test.dart`, `test/widget/workspace/workspace_layout_test.dart`

**Interfaces:**
- Consumes: `ScoreCubit` (`state.song`, `selectedTrackIndex`, `selectTrack`), `PlaybackCubit` (`state.bar`, `state.practice.tracks`, `setMute`, `setSolo`, `seekBar`), Task 2's `BarInfo` and `barsWithNotes`.
- Produces: `class TrackDrawer extends StatefulWidget`, with the constants `kTrackRowHeight = 48.0`, `kBarCellWidth = 14.0`, `kTrackColumnWidth = 184.0`, `kDrawerMaxHeightFraction = 0.4`. `WorkspaceLayout` gains `Widget? drawer`, drawn under `transport` in the score column, in both the three-column and the collapsed layout. Keys used by tests: `ValueKey('trackRow-<index>')`, `ValueKey('barRow-<index>')`, `Key('currentBarMarker')`, `Key('drawerToggle')`.

- [ ] **Step 1: Write the failing widget tests** in `track_drawer_test.dart`, pumping the drawer in an 890 × 626 view with `MockCubit`s for `ScoreCubit` and `PlaybackCubit`. The song is `drumsAndTwoGuitars` with 40 bars (sections `A` at bar 0 and `B` at bar 16, start 0 ms and 32 000 ms), and guitar 1 has notes in even bars only.
  - `lists every track with mute and solo`: rows for `Drums`, `Guitar 1` and `Guitar 2`, each with buttons whose semantics labels are `Mute <name>` and `Solo <name>`.
  - `mute and solo call the cubit`: tapping `Mute Drums` → `setMute(0, true)`; tapping `Solo Guitar 2` while it is soloed → `setSolo(2, false)`.
  - `tapping a guitar track's cell selects it and seeks to that bar`: tap `barRow-2` at `Offset(kBarCellWidth * 5 + 2, 10)` from its top-left → `selectTrack(2)`, then `seekBar(5)`, in that order (`verifyInOrder`).
  - `tapping a drums cell seeks without changing the drawn track`: tap `barRow-0` at bar 3 → `seekBar(3)`, `selectTrack` never called.
  - `tapping a track name selects a guitar track`: tap the `Guitar 2` text → `selectTrack(2)`; tap `Drums` → nothing.
  - `marks the current bar`: `bar: 6` → the left of `currentBarMarker` minus the left of `barRow-1` equals `6 * kBarCellWidth`.
  - `keeps the current bar in view`: `bar: 39` → the grid's horizontal `ScrollPosition.pixels > 0`.
  - `shows section markers with start times`: texts `A 0:00` and `B 0:32`.
  - `collapsed shows only the drawn track's row`: tap `drawerToggle` → only `trackRow-1` remains (selected track 1).
  - `caps its height at 40% of the screen`: a song with 12 tracks → the drawer's height is at most `626 * 0.4`, and its rows scroll.
- Also add to `workspace_layout_test.dart`: `draws the drawer under the transport`: the drawer's top equals the transport's bottom, and both are inside the score column, in both the three-column and the collapsed widths.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/widget/score/track_drawer_test.dart test/widget/workspace`
Expected: FAIL to compile: `track_drawer.dart` not found; `drawer` isn't a `WorkspaceLayout` parameter.

- [ ] **Step 3: Implement `TrackDrawer`.**
  - **Layout.** A header strip on `AppColors.panel` holds the `Tracks` label and the `drawerToggle` chevron; expanded is the default. Below it, a vertically scrolling body: a fixed `kTrackColumnWidth` column of rows (name, `M`, `S`), beside one horizontally scrolling grid. The grid holds one `barRow-<index>` per track, plus a section row under them. The body's height is `min(rows × kTrackRowHeight + section row, screen height × 0.4 − header)`.
  - **Rows.** The drawn track's name is in `AppColors.accent`. `M` and `S` are toggle buttons at least `AccessibleSizes.minTouchTarget` wide, with semantics labels from the l10n keys `muteTrack` and `soloTrack` (`{name}` placeholder).
  - **Grid.** Each `barRow` is a `CustomPaint` that fills `kBarCellWidth`-wide cells where `barsWithNotes` is true, wrapped in a `GestureDetector`. On tap up, bar = `localPosition.dx ~/ kBarCellWidth`. A guitar track that isn't the drawn one gets `await selectTrack` first, then every tap calls `seekBar(bar)`.
  - **Sections and current bar.** The section row places `marker` plus `m:ss` of `startMs` at each section's bar. `currentBarMarker` is a 2 px accent line over the grid at `bar × kBarCellWidth`. When `bar` changes and the marker is outside the visible grid, the grid animates to put it a third of the way in.
  - **Collapsed.** Only the header and the drawn track's row (the first track when nothing is drawn).
  - **Wiring.** `WorkspaceLayout` adds the `drawer` slot under `transport`; `ScorePage` passes `drawer: const TrackDrawer()` when a song is open.

- [ ] **Step 4: Run the tests and the suite**

Run: `flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: track drawer with mute, solo and bar overview grid"
```

---

### Task 8: Track information panel

**Files:**
- Create: `lib/features/score/track_info_panel.dart`
- Delete: `lib/features/score/track_panel.dart`
- Modify: `lib/features/score/score_page.dart`, `lib/l10n/app_en.arb`
- Test: `test/widget/score/track_info_panel_test.dart`, `test/widget/score/score_page_test.dart`

**Interfaces:**
- Consumes: `ScoreCubit` (drawn track), `PlaybackCubit` (`practice.tracks[i].tone`, `setTone`), `tuningLabel` from `lib/features/library/song_list_entry.dart`.
- Produces: `class TrackInfoPanel extends StatelessWidget`, placed in `WorkspaceLayout.trackPanel`.

- [ ] **Step 1: Write the failing tests** in `track_info_panel_test.dart` (`MockCubit`s; the drawn track is `Guitar 1`: 6 strings, tuning `[63, 58, 54, 49, 44, 39]`, tone `overdrive`):
  - `shows the drawn track's name, tuning and string count`: texts `Guitar 1`, `E♭ A♭ D♭ G♭ B♭ E♭` and `6 strings`.
  - `marks the track's tone and changes it`: the `Overdrive` radio is selected; tapping `High gain` → `setTone(1, Tone.highGain)`.
  - `is empty without a drawn track`: no song → no `RadioListTile`.
- In `score_page_test.dart`, replace the Plan 1 test `lists only guitar tracks and switches between them` with `the right panel shows the drawn track` (title of the drawn guitar track in `Key('trackPanel')`), since switching tracks moved to the drawer (Task 7's tests).

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/widget/score`
Expected: FAIL to compile: `track_info_panel.dart` not found.

- [ ] **Step 3: Implement** `TrackInfoPanel`: a `ListView` in a transparent `Material`, with the `Track` heading (l10n `trackHeading`), the name in `titleMedium`, then `Tuning` (l10n `tuning`) with the label, the string count (`stringsCount`), and `Tone` (l10n `tone`) as a `RadioGroup<Tone>` of three dense `RadioListTile`s. Delete `TrackPanel` and its `tracksHeading` use, keeping the key for the drawer header; `ScorePage` passes `trackPanel: const TrackInfoPanel()`.

- [ ] **Step 4: Run the tests and the suite**

Run: `flutter test && flutter analyze`
Expected: all pass, `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: track information panel with tone choice"
```

---

### Task 9: Simulator acceptance

No new code unless a check fails; a failure goes through superpowers:systematic-debugging, and its fix needs a test that failed first.

- [ ] **Step 1: Build and install**

Run: `npm --prefix engine run build && flutter build ios --simulator && xcrun simctl install booted build/ios/iphonesimulator/Runner.app && xcrun simctl launch booted dev.edbrsk.duoscore`
Expected: build succeeds; the app launches on the iPhone Duo simulator.

- [ ] **Step 2: Owner checks**, reported back in one message. Open Collateral Damage from the library, then:
  1. Tap **Play** without touching the score first: sound starts, the cursor follows, and the drawer's current-bar marker moves. If no sound comes until the score is touched, the WebKit media setting from Task 1 isn't enough; stop and report it.
  2. **Speed** 50%: the tempo text halves and playback slows; the 100% shortcut restores it.
  3. **Long-press** on a note, then drag across two bars: a highlighted range appears and the score doesn't scroll. Turn **Loop** on: playback repeats the range. A plain swipe scrolls as before.
  4. **Tone**: switch a guitar track to High gain while playing: the sound changes, and playback continues from the same place.
  5. **Mute** and **solo** in the drawer behave like Guitar Pro.
  6. **Drawer**: tap a cell of another guitar track: that track is drawn and the cursor jumps to the bar. Tap a drums cell: the cursor jumps and the drawn track stays. Collapse and expand the drawer.
  7. **Close the device** in Device Hub while playing: the folded screen shows and playback stops. Reopen it: the same song and track, paused. (This also covers Plan 1's pending fold check.)
  8. **Rotate** so that the vertical bar moves to the left: the layout mirrors, and the score stays centred.
  9. **Relaunch** the app and reopen the song: tone, mute/solo, speed and loop are as you left them.
  10. **Settings**: turn on count-in and the metronome, play and hear both. Open **Licences** and find alphaTab, Bravura and Sonivox SoundFont.

- [ ] **Step 3: Record the results** in the ledger, one line per check, and fix any failure as described above.
