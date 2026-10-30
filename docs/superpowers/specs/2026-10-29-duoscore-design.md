# DuoScore: guitar tab player and editor for iPhone Duo

Date: 2026-10-29
Status: draft for review

## Intent

**DuoScore, the foldable composition suite.** A Flutter app that turns the unfolded iPhone Duo into a guitar tab workstation: open Guitar Pro and MusicXML files, read them as notation over tab, hear them through MIDI, and write new songs the way Guitar Pro does. Songsterr is the reference for reading and playback; Guitar Pro is the reference for editing. Both are simplified to what fits one 7.6" screen.

It is a personal side project. Success is the owner using it to practise and to write riffs on the device.

## Goals (v1)

1. **Open** Guitar Pro files (`.gp3`, `.gp4`, `.gp5`, `.gpx`, `.gp`) and MusicXML (`.musicxml`, `.xml`, `.mxl`).
2. **Read** one guitar track at a time, drawn as standard notation above tab, chosen from the [track drawer](#track-drawer) (as on Songsterr). Other tracks are not drawn.
3. **Play** all tracks of the file over MIDI, with mute and solo per track, a tone per guitar track (clean, overdrive, high gain), speed control, A–B looping and a cursor that follows playback.
4. **Write** new songs and edit opened ones, Guitar Pro style (see [Editor](#editor)).
5. **Retune** a guitar track to another tuning while keeping how it sounds (see [Retuning](#retuning)).
6. **Save** as `.gp`; **export** PDF. (alphaTab writes `.gp` only; Guitar Pro 8 can turn a `.gp` into MusicXML.)
7. **Run only unfolded**: closed, the outer display shows a placeholder logo and "Open your iPhone Duo to continue".

## Non-goals (v1)

- Drawing or editing drum, bass or any non-guitar track. Drums are the next phase and get their own design.
- Audio effects and amp simulation. The tone choice is a MIDI instrument choice. Effect presets stored in Guitar Pro 6+ files are ignored.
- iCloud or any sync. Songs live on the phone.
- A bundled song catalogue.
- 3D views of the instrument.
- Android, iPad and layouts designed for other iPhones.

## Anti-goals

These count as failures even if every feature works:

- The system's vertical bar reads as a dark strip cutting the layout.
- An opened file is overwritten by a save that drops content the app does not understand.
- Notes are silently dropped or moved during retuning without the user being told.
- Tool icons that are not real notation symbols.

## Constraints

- **Toolchain**: Flutter 3.47.8 stable (installed), Xcode 27.1 with the iOS 27.1 SDK. Apps built with this SDK draw edge to edge on both displays and get vertical toolbars below the status bar ([Apple: Prepare](https://developer.apple.com/iphone-duo/prepare/)).
- **Apple's layout rules for iPhone Duo** apply: size from the view or window and re-read it on every resize, no layout decisions from device orientation, idiom or fixed screen sizes, any size-class combination can occur.
- **Flutter has no fold awareness on iOS**: `MediaQuery.displayFeatures` is always empty there ([flutter/flutter#192515](https://github.com/flutter/flutter/issues/192515), open). Resizing and the asymmetric safe areas do reach Dart through `LayoutBuilder` and `MediaQuery.paddingOf`. The hinge and the vertical-bar edge need native bridges.
- **Licences**: bundled code and assets must allow redistribution in an app, and each licence is shown in the app's licence screen: alphaTab (MPL-2.0, shipped unmodified, with a link to its source), the Bravura font (SIL OFL), the Sonivox SoundFont (Apache-2.0). LGPL Dart packages are avoided because the app ships as a single statically linked binary.

## Decisions

### Project structure

- App lives in `/Users/eordonez/Code/sideprojects/duoscore`, iOS target only.
- **Two codebases in one repo**: the Flutter app (Dart, plus Swift in `ios/`), and `engine/`, a TypeScript package that bundles alphaTab with DuoScore's own engine code into web assets the app ships. The split follows the [Music engine](#music-engine): everything that reads or changes a song runs in the engine; everything around the score runs in Flutter.
- Conventions follow `/Users/eordonez/Code/sideprojects/dreambudget_app`: `flutter_bloc` cubits for feature state, `get_it` for dependency injection, `provider` `ChangeNotifier`s for platform signals, `gen-l10n` localisation from day one (English first), design tokens for spacing and sizes, tests in `test/unit` and `test/widget`.
- The iPhone Duo navigation pattern is ported from dreambudget commit `556e8f9` ("Adapt navigation and layout for iPhone Duo"): `ios/Runner/AppDelegate.swift` (`VerticalBarEdgeStreamHandler`), `lib/core/vertical_bar_edge_provider.dart`, `lib/presentation/widgets/glass_capsule.dart`, `app_navigation_rail.dart` and `vertical_bar_app_bar.dart`.

### iPhone Duo behaviour

- **Hinge bridge**: a second `EventChannel`, built like the vertical-bar one, streams the hinge status from UIKit's `UIHingeInteraction` (iOS 27.1 SDK, `UIHinge.h`/`UIHingeInteraction.h`). Its update carries `hinge.status` (`.unknown`, `.closed`, `.partiallyOpen`, `.fullyOpen`), or a nil `hinge` when the view is in a hierarchy without one.
- **Closed**: the app shows only the folded screen (placeholder logo and message). Playback pauses; the open song and editor state are kept.
- **Partially or fully open**: the app works normally, including tent and laptop poses.
- **Split View**: when the window becomes too narrow for three columns, the side panels collapse, the score takes the width, and the app works as a player only. Editing shows "Make DuoScore wider to edit" until the window is wide enough again.

### Screen layout

Mockups: `.superpowers/brainstorm/75036-1793277125/content/editor-layout-v2.html` (layout) and `palette-v3.html` (palette), both approved.

- **Three columns**: tool palette on the left, score in the middle, track information on the right (name, tuning, string count, tone, and which staves to draw: standard notation and tab, each on or off with at least one on, both on by default whatever the file says), with the [track drawer](#track-drawer) along the bottom of the score column.
- **The score is centred on the whole screen** while both side panels are in the same state: they have the same total width, counting the part of a panel that sits under the vertical bar.
- **Each side panel collapses** with a button at its top to a strip holding only the expand button, and the score takes the freed width; the app remembers the choice. The palette exists from the editor plan on; until then there is no left panel, and a vertical bar on the leading edge sits on a strip of panel colour.
- **The panel on the vertical bar's side runs to the screen edge.** The bar's area keeps the panel's own colour; only the system clock and the app's glass tab capsule are drawn there. The panel's controls are inset by the bar's safe-area padding. When the bar is on the leading edge, the arrangement mirrors.
- **Tab capsule** in the vertical bar: Library, Editor, Settings.
- **Transport** under the score, above the track drawer: play/pause, tempo, speed, loop. Tapping the tempo opens the speed control.
- The fold runs through the middle of the score. Notes on the crease stay tappable; no layout change is made for it in v1.

### Track drawer

Modelled on Guitar Pro's track list.

- **A collapsible drawer** along the bottom of the score column. Expanded, it lists every track of the song, drums and bass included, and takes up to about 40% of the screen height (about five rows, then it scrolls). Collapsed, it shrinks to one strip with the selected track's row.
- **Each row**: track name, mute, solo.
- **Bar overview grid** beside the rows: one cell per bar, filled where that track has notes, with the file's section markers (A, B, C… and their start times) under the grid. A marker shows the current bar and follows playback.
- **Tapping a cell** selects that track and moves the cursor to the start of that bar, scrolling the score there. For a non-guitar track the cursor moves and the drawn track stays.

### Music engine

Chosen by the [engine spike](../spikes/2026-10-29-engine-spike.md): on the owner's Guitar Pro 8 files alphaTab reads every technique, and Guitar Pro 8 opens the `.gp` files it writes.

- **alphaTab 1.6.x** (`@coderline/alphatab`, MPL-2.0) is the score model, the file reader (GP3–GP8, MusicXML), the `.gp` writer (`Gp7Exporter`), the renderer (notation over tab, wrapped into lines, Bravura glyphs) and the player.
- **It runs in one `WKWebView`** (`webview_flutter`), created at launch and kept alive for the app's lifetime. The score page shows it; when it is off screen it keeps working (library summaries, playback).
- **The engine** (`engine/`, TypeScript) is the only code that touches alphaTab. It exposes DuoScore's own operations over a JSON message bridge: Dart calls `window.duoscore.handle(message)` through `runJavaScript`, and the engine answers and pushes events through a JavaScript channel named `DuoScore`. Each message has an `id`, a `type` and a `payload`; replies carry the same `id`. The message types are declared once, in `engine/src/protocol.ts`, and mirrored by hand in Dart.
- **Song files reach the engine** from a loopback HTTP server the app runs on `127.0.0.1` (random port), which serves the engine's assets and, read-only, the Documents folder. The engine fetches a song by its path under Documents. If Step 0b shows alphaTab's worker and audio worklet loading from `file://` in `WKWebView`, the server shrinks to serving Documents, or goes.
- **Dart sees songs as summaries**: title, and per track: name, kind, string count, tuning, MIDI program. Notes never cross the bridge.
- **Guitar tracks**: a track counts as guitar when the file gives it strings and frets (a tab staff), or when its MIDI program is in the guitar family (25–32). A file with no guitar track plays its tracks and shows "This song has no guitar track".
- **Automatic fingering**: a guitar part with pitches but no string/fret data (common in MusicXML) gets strings and frets assigned on import, in standard tuning for its string count, preferring the lowest playable position and keeping consecutive notes close together. Retuning step 2 uses the same string-choice logic.

### Playback

- **Player**: alphaTab's synthesizer, which turns the song (all tracks, tempo changes, dynamics and techniques) into MIDI and plays it in the web view. The engine exposes play, pause, seek, speed, loop range, mute/solo, program change, count-in, metronome and a single-note preview for editing, and pushes the playback position so the cursor (drawn by alphaTab) and Flutter's transport stay in step.
- **SoundFont**: `sonivox.sf2` (1.3 MB, Apache-2.0), shipped with alphaTab.
- **Tones** map to General MIDI programs (1-based): Clean = 28 Electric Guitar (clean), Overdrive = 30 Overdriven Guitar, High gain = 31 Distortion Guitar. A guitar track starts with its file's program when that is one of these three, otherwise Clean.
- **Practice settings** (tone, mute/solo, speed, loop, the staves drawn) are kept by the app per file, outside the song file, so practising never modifies or copies a file. When the song is saved, each guitar track's tone is written as its MIDI program.
- **Other tracks** play with their file's program; drums play with the SoundFont's percussion bank.
- **Speed**: 25–150% of the written tempo, with 50/75/100% shortcuts. Tempo changes in the song are followed.
- **Looping**: drag across notes to set an A–B loop; on touch, long-press to start the selection.
- **Count-in** and **metronome** are toggles in Settings.
- **Techniques** sound as alphaTab's player renders them.

### Editor

- **Where it runs**: editing, the bar check, undo/redo and retuning are engine operations on alphaTab's model, followed by a re-render. Flutter draws the palette, the fret pad and the panels, and sends commands. Taps on the score are resolved to bar, voice, beat and string by the engine from alphaTab's layout information.
- **New song**: title, guitar with 6, 7 or 8 strings, tuning, tempo, starting time signature.
- **Guitar tracks**: a song can have several. The track drawer adds, removes and reorders them, the track information panel renames them, and each has its own string count, tuning and tone. Non-guitar tracks from opened files are kept and played but cannot be edited.
- **Tuning presets** include at least the standard tunings for each string count (6: E, E♭, D, C♯, C, B; 7: B, A; 8: F♯, E), the common drop tunings, and a custom tuning per string.
- **Entering notes**: tap a position on a tab string to place the cursor (track, bar, voice, beat, string); type the fret on the pad (two digits in quick succession make 10–24); choose note value and techniques from the palette. Notation is derived from the tab and updates as you type.
- **Palette groups** (as in `palette-v3.html`), drawn with Bravura glyphs:
  - Voice 1–4
  - Note value: whole to 64th, rest
  - Dots, tuplets, ties: dot, double dot, triplet, 5- and 6-tuplets, tie, grace note
  - Rests: whole to 64th
  - Accidentals: double flat, flat, natural, sharp, double sharp
  - Bar: clef, time signature (presets and custom), key signature, repeat start/end, alternate ending, segno/coda, tempo marking
  - Dynamics: ppp to fff, crescendo, diminuendo
  - Guitar techniques: hammer-on, pull-off, slide, bend, vibrato, palm mute, let ring, dead note, ghost note, natural and artificial harmonics, tapping, pick stroke up/down, tremolo picking
  - Articulation: accent, marcato, staccato, tenuto, fermata
- **Voices**: up to four independent rhythm layers per bar, as in Guitar Pro.
- **Time signatures**: a change applies from its bar until the next change.
- **Bar check**: each voice of each bar must add up to the bar's time signature. A bar that is too long or too short is tinted red with the amount it is off (e.g. "⅛ short"). Playback plays bars as written.
- **Bar editing**: insert, delete, copy and paste bars.
- **Undo and redo** cover every edit, including retuning.
- **Autosave** after edits (debounced), to the file the song is saved in (see [Files](#files)).

### Retuning

Retuning applies to one guitar track, keeps every note's pitch and moves the frets.

1. Each note on string *s* moves by the semitone difference between the old and new tuning of *s*: `newFret = fret + oldPitch(s) − newPitch(s)`. Standard D → Standard E lowers every fret by 2.
2. A note whose `newFret` is below 0 or above the track's highest fret (24 by default) moves to another string that no voice uses at that moment, if one can play it. Notes joined by a hammer-on, pull-off or slide move together; when the group cannot stay on one string, the technique is removed.
3. A note that no string can play keeps its original fret and is drawn in red.
4. Changing string count (e.g. 7 → 6) maps strings by pitch order; notes on removed strings go through steps 2 and 3.
5. After retuning, notes moved to another string are drawn in amber and unplayable ones in red, until the next edit. When either count is not zero, a message gives both counts (e.g. "12 notes moved to another string, 3 can't be played") and offers **Undo** and **Move track up/down an octave**, which reruns the retune on that track.

### Files

- Songs live in the app's Documents folder, visible in the Files app under On My iPhone › DuoScore (`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`).
- The app registers document types for every supported extension, so Open In / AirDrop / Files offer DuoScore; an incoming file is copied into Documents.
- **Opened files are never overwritten.** The first edit to an opened file (any change to notes, bars, tracks or tuning) creates `<name> (DuoScore).gp` beside it, and autosave writes to that copy from then on. The library lists both. Songs created in the app save to `<title>.gp`.
- **Exports**, shared through the iOS share sheet: `.gp`, and PDF with title, tempo, tuning and notation over tab as alphaTab lays it out in pages.

### Library screen

A list of the songs in Documents showing title, tuning and string count, and a **New song** button.

## Step 0: spikes

**Step 0a (done)** compared `crisp_notation` 0.13.0 with alphaTab 1.6.1 on the owner's files and the alphaTab test corpus, and chose alphaTab. Results: `docs/superpowers/spikes/2026-10-29-engine-spike.md`.

**Step 0b** is a throwaway build, run before any task that depends on the web view. On the iPhone Duo simulator, it checks:

1. alphaTab in a `WKWebView` draws one guitar track of Collateral Damage as notation over tab, wrapped into lines.
2. It plays that song with `sonivox.sf2`, in time, with the cursor following.
3. It loads from `file://` or needs the loopback server; the result settles the [Music engine](#music-engine) choice.
4. It takes this long to load and draw the song: the time is recorded.
5. The bridge round-trip time for a small message: recorded.

If alphaTab cannot draw or play inside `WKWebView` on the device, the plan stops and the owner decides.

## Test assets

- **Devices**: the iPhone Duo simulator in Xcode 27.1 is the default test target; the owner also has a physical iPhone Duo.
- **Guitar Pro 8**: the owner has it, for checking saved `.gp` files and comparing rendering.
- **The owner's songs**: `/Users/eordonez/Desktop/2. Guitar Pro Files/`, 21 Guitar Pro 8 files. The primary one is `07 Collateral Damage.gp`: 7 guitar tracks, all 6-string in E♭ standard, 153 bars, 19 time-signature changes, 4,030 notes, with hundreds of bends, vibratos, palm mutes, let rings, slides and hammer-ons.
- **These are purchased Sheet Happens transcriptions** and must never be committed or bundled. Tests that use them read the path from the environment variable `DUOSCORE_PRIVATE_SAMPLE` and skip when it is unset.
- **The alphaTab test corpus** (`test-data/` from github.com/CoderLine/alphaTab, MPL-2.0) covers GP3–GP8 and MusicXML features, several voices and 7-string tracks. It lives in the git-ignored `test_assets_private/` and is not committed either.
- **Committed fixtures** are generated by the engine's own tests from alphaTex (alphaTab's text format), so the repo holds no third-party song files.

## Left to the builder

- What the app does when the hinge status is unknown or the hierarchy has no hinge.
- The Split View width at which the side panels collapse.
- Exact panel widths, colours and typography, staying within the approved mockups.
- Default fret count per string count, and the full tuning preset list beyond the minimum.
- Settings contents beyond count-in, metronome and default tone.
- Library sorting and search.

## Later phases (separate designs)

- **Drums**: drum tracks drawn and edited as drum notation, with their own palette and input. The v1 model already records each track's instrument kind, so drums add a view and an editor without changing the model.
- **Sound bank**: the three tones sound alike with Sonivox. A throwaway comparison in the app (GeneralUser GS, MuseScore General, FluidR3 GM, Sonivox) lets the owner choose by ear the bank closest to Guitar Pro 8's MIDI sound; the chosen bank replaces Sonivox and its licence joins the licence screen.

## References

- Inspiration: [tocarlagralla.cat](https://www.tocarlagralla.cat) (static web app: abcjs rendering, Web Audio sampler with look-ahead scheduling, A–B loop by dragging over notes, speed shortcuts, count-in).
- Apple: [Get ready for iPhone Duo](https://developer.apple.com/iphone-duo/), [Prepare](https://developer.apple.com/iphone-duo/prepare/), tech talks [111461](https://developer.apple.com/videos/play/tech-talks/111461/), [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111464](https://developer.apple.com/videos/play/tech-talks/111464/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/).
- Packages: [alphaTab](https://alphatab.net) ([source](https://github.com/CoderLine/alphaTab)), [webview_flutter](https://pub.dev/packages/webview_flutter).
