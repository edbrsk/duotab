# DuoScore Plan 9: Mixer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The track drawer's mixer gets dB faders, real level meters, pan knobs and a Master row, read from and written to Guitar Pro files the way Guitar Pro does.

**Architecture:**
- **Engine values.** On open, the engine reads each track's exact stored volume and pan, and the master volume, from the file's `score.gpif`. It reports them in dB and −1…1 pan in the song summary.
- **Live mixing.**
  - A track's dB plays as an alphaTab mix volume on top of MIDI baked at the file's level.
  - Pan is a per-channel override in the synth worker, so it holds through seeks and new MIDI.
  - The master is a gain on the page's output limiter.
- **Meters.** DuoScore serves its own `alphaTab.worker.mjs`, which imports alphaTab's unmodified core, measures each MIDI channel's peak after fader and pan, and posts timestamped level frames. The page releases each frame when playback reaches its time and sends `levels` events to the app.
- **App.** The practice settings hold dB, pan and master. The drawer's mixer column shows a fader with its meter, a dB readout and a pan knob per track, plus a Master row.

**Tech Stack:** as Plan 8. alphaTab 1.6.1 internals used, and where:
- `TinySoundFont.prototype` is reached through `AlphaSynth.prototype.exportAudio(...)._synth`; `Voice.prototype` through the first voice the synth creates. Both are inside the worker.
- `AlphaSynthBase.prototype.onSampleRequest` (exported as `alphaTab.synth.AlphaSynthBase`).
- `Environment.createWebWorker` (exported `alphaTab.Environment`), to get the page's `Worker`.

`DecompressionStream('deflate-raw')` reads the `.gp` zip, both in WKWebView and in Node.

**Spec:** `docs/superpowers/specs/2026-10-30-duoscore-mixer-design.md`, extending `docs/superpowers/specs/2026-10-29-duoscore-design.md` (Mixer, Practice settings).

**Branch:** `plan-9-mixer`, from `main`.

## Global Constraints

Plans 1–8's Global Constraints all apply. In addition:

- **Fader range:** −∞, then −40 dB to +10 dB. Positions below 0.02 of the width are −∞. From 0.02 to 1 the fader is linear in dB, from −40 to +10, so 0 dB sits at 0.804.
- **Readout:** one decimal with a sign and U+2212 for minus: `0.0 dB`, `+6.0 dB`, `−6.0 dB`, `−∞ dB`. Dragging moves in 0.5 dB steps. A dB read from a file snaps to the nearest 0.5 dB, with ties toward 0 dB.
- **Pan:** −1 (full left) … 0 … 1 (full right). The label is `L50`…`C`…`R50`, rounding `|pan| × 50`, shown only while the knob is turned. Drag steps are 0.02.
- **Double-tap:** a fader goes to 0 dB, a knob to centre.
- **Meter:**
  - **Scale:** the fader's own, so 0 dBFS reaches the 0 dB tick and −40 dBFS the left end of the scale.
  - **Colours:** blue below −6 dBFS, yellow from −6, red from −1.
  - **Movement:** rises at once and falls 20 dB per second. Below −60 dBFS it shows nothing.
  - **What it measures:**
    - **Track meter:** after the track's fader and pan, including the engine's 2× output gain, before the master.
    - **Master meter:** after the master fader and the 2× gain, before the limiter.
- **Guitar Pro mapping**, for `score.gpif` values:
  - **Track volume:** `dB = 50 · stored − 40`, and `stored = (dB + 40) / 50`, clamped to 0–1. −∞ writes 0.
  - **Master volume:** `dB = 40 · (stored − 0.76)`.
  - **Pan:** `pan = 2 · stored − 1`, and `stored = (pan + 1) / 2`.
- **Files without `score.gpif`** (GP3–5, GPX, MusicXML): a track's dB is `60 · log10(volume / 12)`, from alphaTab's 0–16 `playbackInfo.volume`. Volume 0 is −∞. Pan is `(balance − 8) / 8`, and the master is 0 dB.
- **0 dB reference:** 0 dB sounds like MIDI volume 96 (alphaTab volume 12), as every track of the owner's songs plays today.
- **Practice JSON:**
  - A track gets `"volumeDb"` (a number, or `"-inf"`) and `"pan"` (a number). Each is absent to use the file's.
  - Settings get `"masterDb"`.
  - A legacy `"volume"` (0–16) converts to `60 · log10(volume / fileVolume)` dB, where `fileVolume` is the track summary's `volume`; 0 is −∞.
- **Files:** a mix-only change never writes a file. `exportGp` writes each track's exact volume and pan; `exportFileGp` is unchanged.
- **alphaTab ships unmodified:** `alphaTab.core.mjs` and the rest stay alphaTab's own files. `alphaTab.worker.mjs` becomes DuoScore's entry, which imports `./alphaTab.core.mjs` and then calls `Environment.initializeWorker()`, as alphaTab's does.
- **Layout:** the shared track column keeps name, M, S and ⋮. The mixer column holds, per row, the fader with its meter under it, the dB readout and the pan knob. The Master row adds `Master` to the track column, and a fader, readout and meter to the mixer column.

## Review Focus

1. **Meters run with the sound, not ahead of it.** The worker renders up to about 500 ms early. A meter must show a hit when it's heard, at any speed. Task 3 `releases frames when playback reaches them`.
2. **Pan holds through anything that resets the synth:** a seek back, loop, stop and play, new MIDI after a tone change, and undo. Task 2 `pan holds after the song's own pan message replays`; Task 3 `pan is sent again after new MIDI`.
3. **Mute, solo and two channels per track:** a muted or soloed-out track's meter shows nothing. A track's notes on its secondary channel (bends, whammy) count toward its meter. Task 2 `a muted channel measures nothing`; Task 3 `a track's level is the louder of its two channels`.
4. **Export writes exact values, and playback isn't changed by exporting.** After `exportGp`, the live MIDI still bakes the file's level. Task 3 `export writes the faders and leaves the MIDI's level`.
5. **Old practice settings:** a song mixed before this plan keeps its sound. 12 of a file's 12 reads 0.0 dB, and 6 of 12 reads −18.0 dB. Task 4 `a legacy volume becomes the dB that sounds the same`.

---

### Task 1: File levels in dB

**Files:**
- Create: `engine/src/mix_values.ts`, `engine/src/gp_mixer.ts`
- Modify: `engine/src/protocol.ts` (`TrackSummary`, `SongSummary`), `engine/src/summary.ts` (`describeOpened`), `engine/src/main.ts` (`open`: read the mixer from the bytes it fetched)
- Test: `engine/test/mix_values.test.ts`, `engine/test/gp_mixer.test.ts`, `engine/test/summary.test.ts`

**Interfaces:**
- Produces, in `mix_values.ts` (`null` dB is −∞):
  - `trackDbFromStored(stored: number): number`
  - `storedFromTrackDb(db: number | null): number`
  - `masterDbFromStored(stored: number): number`
  - `panFromStored(stored: number): number`
  - `storedFromPan(pan: number): number`
  - `dbFromVolume(volume: number): number | null` (the 0–16 law)
- Produces, in `gp_mixer.ts`: `type GpMixer = { tracks: { volume: number; pan: number }[]; master: number | null }` (stored 0–1 values), and `readGpMixer(bytes: Uint8Array): Promise<GpMixer | null>`. It returns null for anything that isn't a zip holding `Content/score.gpif`. Tracks come in the order of `MasterTrack › Tracks`, which is alphaTab's track order.
- Produces: `TrackSummary` gains `volumeDb: number | null` and `pan: number`; `SongSummary` gains `masterDb: number`. `summarize` (library) fills them by the 0–16 law, `open` from the file. Signature: `describeOpened(score, fileName, unplayable?: number, mixer?: GpMixer | null)`.

- [ ] **Step 1: Write the failing tests.**
  - `mix_values.test.ts`:
    - `Guitar Pro's track volume is linear in dB`: `trackDbFromStored` of 0.92, 0.795, 0.68 and 0.4 gives 6, −0.25, −6 and −20, to 6 digits.
    - `storedFromTrackDb` of 0, −6 and null gives 0.8, 0.68 and 0; of +20 it gives 1.
    - `masterDbFromStored(0.76)` is 0, and of 0.61 it's −6.
    - `panFromStored` of 0, 0.5 and 1 gives −1, 0 and 1. `storedFromPan(-1)` is 0.
    - `dbFromVolume` of 12, 6 and 0 gives 0, −18.06 (to 2 digits) and null.
  - `gp_mixer.test.ts`:
    - `reads track volume and pan from a file alphaTab wrote`: take `score(twoGuitarsAndDrums)`, set track 0's `playbackInfo.volume = 10.88` and `balance = 0`, export with `Gp7Exporter`, then `readGpMixer`. Track 0 is `{ volume: 0.68, pan: 0 }` to 6 digits and track 1 is `{ volume: 0.75, pan: 0.5 }`. It has 3 tracks, and the master is null.
    - `reads the master from Guitar Pro's mixer`: a zip built in the test (a stored, uncompressed entry) holding a minimal `score.gpif` with `<MasterTrack><Tracks>0</Tracks>…<Effect id="I01_VolumeAndPan"><Parameters>0.61 0.5</Parameters>` and one `<Track id="0">` whose `ChannelStrip › Parameters` has 0.795 at index 12 and 0.5 at index 11. The master is 0.61 and the track's volume 0.795.
    - `anything else reads nothing`: input that isn't a zip, such as `new TextEncoder().encode('<score-partwise/>')`, gives null.
  - `summary.test.ts`: `open reports the file's levels`. A `describeOpened` with a `GpMixer` of tracks `[{volume: 0.68, pan: 0}]` and master 0.61 gives `volumeDb` −6, `pan` −1 and `masterDb` −6. Without a mixer, a track at volume 12 and balance 8 gives 0 and 0, and `masterDb` 0.

- [ ] **Step 2: Run them.** `npm --prefix engine test -- mix_values gp_mixer summary`. Expected: FAIL. The new modules can't be resolved, and the summary has no `volumeDb`.

- [ ] **Step 3: Implement.** `readGpMixer`:
  - Find the zip's end-of-central-directory record, and from it the `Content/score.gpif` entry.
  - Inflate it with `new DecompressionStream('deflate-raw')` for method 8, or take it as is for method 0.
  - Parse with `DOMParser` where it exists. Elsewhere (Node), regular expressions over the gpif are enough, as the gpif is machine-written.

  `open` calls `readGpMixer(bytes)` before `api.load` and passes the result to `describeOpened`. A failure to read it is a null, never a failed open.

- [ ] **Step 4: Run them.** Same command. Expected: PASS. Then `npm --prefix engine test`, with all passing.

- [ ] **Step 5: Commit.** `feat(engine): report each track's file volume and pan in dB, and the master's`

### Task 2: The synth worker's pan and levels

**Files:**
- Create: `engine/src/worker/synth_hooks.ts`, `engine/src/worker/entry.ts`
- Modify: `engine/build.mjs`. Bundle `src/worker/entry.ts` to `assets/engine/alphatab/alphaTab.worker.mjs`, with `@coderline/alphatab` aliased to `./alphaTab.core.mjs` and kept external, and stop copying alphaTab's `alphaTab.worker.mjs`.
- Test: `engine/test/synth_hooks.test.ts`

**Interfaces:**
- Produces: `type LevelFrame = { cmd: 'duoscore.levels'; time: number; channels: [channel: number, left: number, right: number][]; master: [number, number] }`. Peaks are linear, before the page's gain. `time` is the sequencer's song time in ms at the end of the block.
- Produces: `type PanMessage = { cmd: 'duoscore.pan'; channel: number; pan: number | null }`. `pan` is −1…1; null drops the override, back to the song's own pan.
- Produces: `installSynthHooks(at: typeof alphaTab, post: (frame: LevelFrame) => void): { setPan(channel: number, pan: number | null): void }`. It patches:
  - `TinySoundFont.prototype.channelSetPan`, so an override wins over the song's pan message;
  - `Voice.prototype.render`, to add each voice's contribution to its channel's peak;
  - `TinySoundFont.prototype.synthesize`, for the mixed peak;
  - `AlphaSynthBase.prototype.onSampleRequest`, to post one frame per request while playing, then reset the peaks.

  An override is synth pan `0.5 + pan / 2`.
- `entry.ts`: imports `@coderline/alphatab`, calls `installSynthHooks(alphaTab, (f) => postMessage(f))`, listens for `duoscore.pan` messages, then calls `alphaTab.Environment.initializeWorker()`.

- [ ] **Step 1: Write the failing tests.** They drive a synth the way the exporter makes one: `AlphaSynth.prototype.exportAudio.call({ synthesizer: { presets: [] } }, options, midi, [], new Map())`, loaded with GeneralUser GS from `engine/soundfont/GeneralUser-GS.sf2`, with `render(ms)` as the clock.
  - `measures each channel's level after its pan`: two tracks, A playing and B with rests only, with pan −1 set on A's primary channel. A's left peak is above 0.01, its right peak 0, and B's channel doesn't appear.
  - `pan holds after the song's own pan message replays`: set an override, then dispatch CC10 = 64 on that channel through the synth's `processMidiMessage`. The channel's `panOffset` is still `override − 0.5`.
  - `a null pan gives the song's own back`: after `setPan(ch, null)` and CC10 = 0, `panOffset` is −0.5.
  - `a muted channel measures nothing`: with `channelSetMute(ch, true)`, that channel's peaks are 0.
  - `the master is the mixed peak`: for one playing track, the master peak is at least the larger of its channel peaks.

  The `onSampleRequest` frame is checked in Task 3's end-to-end run, since the exporter doesn't call it.
- [ ] **Step 2: Run them.** `npm --prefix engine test -- synth_hooks`. Expected: FAIL, the module can't be resolved.
- [ ] **Step 3: Implement** `synth_hooks.ts` and `entry.ts`, and make the `build.mjs` change.
- [ ] **Step 4: Verify.**
  - `npm --prefix engine test -- synth_hooks`. Expected: PASS.
  - `npm --prefix engine run build && head -c 300 assets/engine/alphatab/alphaTab.worker.mjs && grep -c "initializeWorker" assets/engine/alphatab/alphaTab.worker.mjs`. Expected: an import of `./alphaTab.core.mjs`, and 1.
- [ ] **Step 5: Commit.** `feat(engine): the synth worker pans channels and measures their levels`

### Task 3: The engine mixes in dB, pans, and reports levels

**Files:**
- Create: `engine/src/levels.ts`
- Modify:
  - `engine/src/mixer.ts`: dB factor, pan, and export levels.
  - `engine/src/output_level.ts`: `Limiter.gain` becomes settable.
  - `engine/src/protocol.ts`: `TrackMix`, the `setMaster` request and the `levels` event.
  - `engine/src/main.ts`:
    - capture the worker;
    - `setMaster`;
    - meter release on `playerPositionChanged`;
    - `exportGp` through `mixer.withFileLevels`.
- Test: `engine/test/mixer.test.ts`, `engine/test/levels.test.ts`, `engine/test/output_level.test.ts`

**Interfaces:**
- Consumes: Task 1's `storedFromTrackDb` and `storedFromPan`; Task 2's `LevelFrame` and `PanMessage`.
- Produces:
  - **`TrackMix`:** `{ index, mute, solo, program, volumeDb: number | null, pan: number }`. `volume` goes.
  - **`MixerApi` additions:** `setChannelPan(channel: number, pan: number | null): void`.
  - **`Mixer` methods:** `withFileLevels<T>(run: () => T): T` sets each mixed track's `playbackInfo.volume = storedFromTrackDb(db) · 16` and `balance = storedFromPan(pan) · 16` for `run`, then puts them back.
- Produces, in `levels.ts`: `class LevelMeter`.
  - `constructor(outputGain: () => number)` — the 2× times the master.
  - `add(frame: LevelFrame)`.
  - `release(time: number, tracks: { primaryChannel: number; secondaryChannel: number }[], masterGain: number): Levels | null`.
  - `clear()`.
  - `type Levels = { tracks: ([number, number] | null)[]; master: [number, number] | null }` is in dBFS rounded to 0.1. Null below −60.
- Produces: request `setMaster { volumeDb: number | null }`. Event `levels` with `Levels`, at most every 40 ms while playing, and one all-null `levels` when playback pauses or stops.

- [ ] **Step 1: Write the failing tests.**
  - `mixer.test.ts`. Replace the two `volume` tests:
    - `a level plays as its dB over the MIDI's`: baked at 12, `volumeDb` −6 gives factor `10 ** (-6 / 20)` to 6 digits. Baked at 10, 0 dB gives `(96 / 80) ** 3`. Null gives 0.
    - `pan goes to both of a track's channels`: `setChannelPan` is called with (primary, −0.5) and (secondary, −0.5).
    - `pan is sent again after new MIDI`: after a program change regenerates, `setChannelPan` is called again with the track's pan.
    - `a silent file track is baked at 0 dB once its fader rises`: baked at 0, `volumeDb` −6 regenerates with `playbackInfo.volume` 12.
    - `export writes the faders and leaves the MIDI's level`: inside `withFileLevels`, track 0 at −6 dB and pan −1 reads `volume` 10.88 and `balance` 0. Afterwards it's back to its baked 12 and 8.
  - `levels.test.ts`:
    - `releases frames when playback reaches them`: frames at times 100 and 600 give, at `release(300, …)`, the first frame's levels. At `release(700, …)` you get the second.
    - `a track's level is the louder of its two channels`: channels 0 = 0.1 and 1 = 0.5, for a track on channels 0 and 1 with gain 2, give `20·log10(1.0)` = 0.0 dBFS.
    - `master shows the mix after the master fader`: master peak 0.25 with gain 2 and master −6 dB gives about −12.0 dBFS.
    - `quiet is nothing`: a peak of 0.0001 gives null.
  - `output_level.test.ts`: `a new gain applies to the next block`. A `Limiter` with gain set to 1 passes 0.1 as 0.1.
- [ ] **Step 2: Run them.** `npm --prefix engine test -- mixer levels output_level`. Expected: FAIL on the new tests.
- [ ] **Step 3: Implement.**
  - **Factor:** `levelFactor(db, baked) = db === null ? 0 : 10 ** (db / 20) · (96 / midi(baked)) ** 3`, with `midi(v) = min(127, v · 8)`. It replaces `volumeFactor`.
  - **Worker capture:** in `main.ts`, wrap `alphaTab.Environment.createWebWorker` before `new AlphaTabApi`. Keep the `Worker` it returns, listen for `duoscore.levels` on it, and give `setChannelPan` a `postMessage` of `PanMessage`.
  - **Master:** the limiter's gain is `2 · 10 ** (db / 20)`, and 0 for −∞.
- [ ] **Step 4: Verify.**
  - `npm --prefix engine test`, all passing.
  - `npx --prefix engine tsc --noEmit -p engine`, no errors.
  - Build and run on the simulator: playing *Parade of Rage* shows `levels` events in the bridge (log the first three with `debugPrint` while checking, then remove the log).
- [ ] **Step 5: Commit.** `feat(engine): mix in dB with live pan, a master gain and level events`

### Task 4: The app's mix in dB

**Files:**
- Create: `lib/features/playback/mix_level.dart`, `lib/features/playback/levels.dart`
- Modify:
  - `lib/engine/protocol.dart`: `TrackSummary.volumeDb` / `pan`, `SongSummary.masterDb`, `TrackMix`, `Levels`.
  - `lib/engine/engine_bridge.dart`: `setMaster`.
  - `lib/features/playback/practice_settings.dart`, `resolve_practice.dart`, `playback_cubit.dart`.
- Test: `test/unit/features/playback/mix_level_test.dart`, `resolve_practice_test.dart`, `practice_store_test.dart`, `playback_cubit_test.dart`

**Interfaces:**
- Consumes: Task 3's `TrackMix`, `setMaster` and `levels` shapes; Task 1's summary fields.
- Produces, in `mix_level.dart` (−∞ is `double.negativeInfinity`):
  - `double faderPosition(double db)`
  - `double dbAtPosition(double position)` (snapped)
  - `double snapDb(double db)`
  - `String dbLabel(double db)`
  - `String panLabel(double pan)`
  - `double dbFromLegacyVolume(int volume, int fileVolume)`
- Produces, in `levels.dart`: `class MeterLevel { final double left; final double right; }` in dBFS, with −∞ for none. `class Levels { final List<MeterLevel?> tracks; final MeterLevel? master; }` and `Levels.fromJson`. `double meterShown({required double shown, required Duration since, required double incoming})` falls 20 dB/s and rises at once.
- Produces:
  - **`TrackPractice`:** gains `volumeDb` and `pan` (`double?`, null for the file's); `volume` goes, and the legacy JSON `volume` is kept as `legacyVolume` for resolution only.
  - **`PracticeSettings`:** gains `masterDb`.
  - **`PlaybackCubit`:** `setVolumeDb(int track, double db, {bool save = true})`, `setPan(int track, double pan, {bool save = true})`, `setMasterDb(double db, {bool save = true})`, and `ValueListenable<Levels?> get levels`. `setVolume` goes.

- [ ] **Step 1: Write the failing tests.**
  - `mix_level_test.dart`:
    - `faderPosition(0)` is 0.804 to 3 digits and `faderPosition(10)` is 1. `faderPosition(-inf)` is 0.
    - `dbAtPosition(0.01)` is −∞, and `dbAtPosition(0.804)` is 0.
    - `snapDb(-0.25)` is 0 and `snapDb(-0.26)` is −0.5.
    - `dbLabel` gives `0.0 dB`, `+6.0 dB`, `−6.0 dB` and `−∞ dB`.
    - `panLabel` gives `C` for 0, `L50` for −1 and `R25` for 0.5.
  - `resolve_practice_test.dart`:
    - `a legacy volume becomes the dB that sounds the same`: a legacy 12 over file volume 12 gives 0.0; 6 gives −18.0; 0 gives −∞.
    - `the file's levels when none are saved`: a summary with `volumeDb` −6, `pan` −1 and `masterDb` −6 resolves to those.
  - `practice_store_test.dart`: `−∞ survives saving` — `volumeDb` −∞ round-trips as `"-inf"`.
  - `playback_cubit_test.dart`:
    - `setVolumeDb sends the track's dB and pan`: the engine gets `TrackMix(volumeDb: -6.0, pan: 0.0, …)`.
    - `setPan saves on release`: with `save: false` nothing is stored; with the default it is.
    - `setMasterDb sends setMaster`.
    - `a levels event updates the meters without a new state`: no state is emitted, and `levels.value!.tracks[0]!.left` is −12.0.
    - `−∞ sends a null dB`.
- [ ] **Step 2: Run them.** `flutter test test/unit/features/playback`. Expected: FAIL to compile on the new names.
- [ ] **Step 3: Implement.**
  - **Practice settings JSON** as in Global Constraints.
  - **`resolvePractice`:** works out each track's `volumeDb` and `pan`, and the settings' `masterDb`. Snap file dBs with `snapDb`.
  - **On open:** the cubit sends `setMaster` after `setTracks`.
- [ ] **Step 4: Run them.** `flutter test`, then `flutter analyze`. Expected: all passing, no issues. Fix the call sites of `TrackPractice.volume` and `setVolume`; Task 5 replaces the drawer's `_VolumeRow`. Until then, map its slider to `setVolumeDb(dbAtPosition(v / 16))`, so the app builds.
- [ ] **Step 5: Commit.** `feat: practice settings and playback in dB, with pan, master and levels`

### Task 5: The mixer rows

**Files:**
- Create: `lib/features/score/mixer_row.dart` (`MixerRow`, `MasterRow`, `_Fader`, `_Meter`, `_PanKnob`)
- Modify:
  - `lib/features/score/track_drawer.dart`: replace `_VolumeRow`, and add the Master row to both columns in mixer mode.
  - `lib/l10n/app_en.arb`, then run `flutter gen-l10n`.
  - `docs/superpowers/specs/2026-10-29-duoscore-design.md`: in Mixer (line 83) and Practice settings (line 102), "volume slider … 0–100%" becomes dB faders, pan and Master, with a reference to the mixer design.
- Test: `test/widget/score/mixer_row_test.dart`, `test/widget/score/track_drawer_test.dart`

**Interfaces:**
- Consumes: Task 4's cubit methods, `levels`, and `mix_level.dart`.
- Produces: `MixerRow({required TrackSummary track, required double volumeDb, required double pan})` and `MasterRow({required double volumeDb})`.
  - Keys: `fader-<index>`, `pan-<index>`, `meter-<index>`, `fader-master`, `meter-master`.
  - Strings: `master` = "Master"; `volumeOf` = "Volume of {name}: {db}"; `panOf` = "Pan of {name}: {pan}"; `masterVolume` = "Master volume: {db}".

- [ ] **Step 1: Write the failing tests.**
  - `mixer_row_test.dart`:
    - `shows the level in dB`: −6 shows `−6.0 dB`.
    - `dragging the fader moves in half decibels and saves on release`: drag `fader-0` and expect `setVolumeDb` calls with values that are multiples of 0.5, the last with `save: true`.
    - `double-tapping the fader returns it to 0 dB`.
    - `turning the knob shows its side, and double-tap centres it`: drag `pan-0` right and expect `R…` visible during the drag and gone after. A double-tap calls `setPan(0, 0)`.
    - `the meter follows the levels`: a `levels` value of −12 dBFS on track 0 paints a bar ending at `faderPosition(-12)` of the width (check through the painter's `levelFraction`).
    - `semantics read the level`: the fader's label is "Volume of Guitar 1: −6.0 dB".
  - `track_drawer_test.dart`: `the mixer has a Master row`. In mixer mode, `Master` is in the track column and `fader-master` in the mixer column. Outside mixer mode, neither is.
- [ ] **Step 2: Run them.** `flutter test test/widget/score`. Expected: FAIL; `MixerRow` doesn't exist.
- [ ] **Step 3: Implement.**
  - **Meter:** two 3 pt bars under the fader track, coloured as in Global Constraints. It repaints with a `Ticker` only while a level is above the floor.
  - **Knob:** a 26 pt ring with a pointer at `pan × 135°`. Horizontal drag changes the pan, at 0.02 per 4 pt.
  - **Touch targets:** keep `AccessibleSizes.minTouchTarget`.
- [ ] **Step 4: Run them.** `flutter test`, then `flutter analyze`. Expected: all passing, no issues.
- [ ] **Step 5: Commit.** `feat: dB faders with meters, pan knobs and a Master row in the mixer`

## Owner checks on the simulator

1. *Parade of Rage* opens with the three guitars and Master at `0.0 dB`, pan centred, and sounds as before.
2. While it plays, each meter moves with its guitar: Guitar 1 is silent until bar 5, and the meters stay in time with the sound.
3. Guitar 2 at `−6.0 dB` sounds clearly quieter at once, with no glitch, and its meter drops.
4. Guitar 1 at `L50` and Guitar 3 at `R50` sound apart on headphones, and stay apart after a seek, a loop and a tone change.
5. After relaunching, the levels and pan are as you left them, and changing only the mix created no "Edited" copy.
6. After an edit (so the song saves) and Export as `.gp`, Guitar Pro opens the file showing the same dB and pan.
7. Master at `+10 dB` on the loudest passage turns the Master meter red without crackling.
