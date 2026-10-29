# DuoTab: guitar tab player and editor for iPhone Duo

Date: 2026-10-29
Status: draft for review

## Intent

A Flutter app that turns the unfolded iPhone Duo into a guitar tab workstation: open Guitar Pro and MusicXML files, read them as notation over tab, hear them through MIDI, and write new songs the way Guitar Pro does. Songsterr is the reference for reading and playback; Guitar Pro is the reference for editing. Both are simplified to what fits one 7.6" screen.

It is a personal side project. Success is the owner using it to practise and to write riffs on the device.

## Goals (v1)

1. **Open** Guitar Pro files (`.gp3`, `.gp4`, `.gp5`, `.gpx`, `.gp`) and MusicXML (`.musicxml`, `.xml`, `.mxl`).
2. **Read** one guitar track at a time, drawn as standard notation above tab, chosen from the track panel (as on Songsterr). Other tracks are not drawn.
3. **Play** all tracks of the file over MIDI, with mute and solo per track, a tone per guitar track (clean, overdrive, high gain), speed control, A–B looping and a cursor that follows playback.
4. **Write** new songs and edit opened ones, Guitar Pro style (see [Editor](#editor)).
5. **Retune** a guitar track to another tuning while keeping how it sounds (see [Retuning](#retuning)).
6. **Save** as `.gp`; **export** PDF and MusicXML.
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
- **Licences**: bundled assets must allow redistribution in an app (the Bravura font is SIL OFL; the SoundFont's licence must be recorded alongside it). LGPL Dart packages are avoided because the app ships as a single statically linked binary.

## Decisions

### Project structure

- App lives in `/Users/eordonez/Code/sideprojects/duotab`, iOS target only.
- Conventions follow `/Users/eordonez/Code/sideprojects/dreambudget_app`: `flutter_bloc` cubits for feature state, `get_it` for dependency injection, `provider` `ChangeNotifier`s for platform signals, `gen-l10n` localisation from day one (English first), design tokens for spacing and sizes, tests in `test/unit` and `test/widget`.
- The iPhone Duo navigation pattern is ported from dreambudget commit `556e8f9` ("Adapt navigation and layout for iPhone Duo"): `ios/Runner/AppDelegate.swift` (`VerticalBarEdgeStreamHandler`), `lib/core/vertical_bar_edge_provider.dart`, `lib/presentation/widgets/glass_capsule.dart`, `app_navigation_rail.dart` and `vertical_bar_app_bar.dart`.

### iPhone Duo behaviour

- **Hinge bridge**: a second `EventChannel`, built like the vertical-bar one, streams the hinge status from UIKit's `UIHingeInteraction` (iOS 27.1 SDK, `UIHinge.h`/`UIHingeInteraction.h`). Its update carries `hinge.status` (`.unknown`, `.closed`, `.partiallyOpen`, `.fullyOpen`), or a nil `hinge` when the view is in a hierarchy without one.
- **Closed**: the app shows only the folded screen (placeholder logo and message). Playback pauses; the open song and editor state are kept.
- **Partially or fully open**: the app works normally, including tent and laptop poses.
- **Split View**: when the window becomes too narrow for three columns, the side panels collapse, the score takes the width, and the app works as a player only. Editing shows "Make DuoTab wider to edit" until the window is wide enough again.

### Screen layout

Mockups: `.superpowers/brainstorm/75036-1793277125/content/editor-layout-v2.html` (layout) and `palette-v3.html` (palette), both approved.

- **Three columns**: tool palette on the left, score in the middle, track panel on the right.
- **The score is centred on the whole screen**: the two side panels have the same total width, counting the part of a panel that sits under the vertical bar.
- **The panel on the vertical bar's side runs to the screen edge.** The bar's area keeps the panel's own colour; only the system clock and the app's glass tab capsule are drawn there. The panel's controls are inset by the bar's safe-area padding. When the bar is on the leading edge, the arrangement mirrors.
- **Tab capsule** in the vertical bar: Library, Editor, Settings.
- **Transport** under the score: play/pause, tempo, speed, loop, tone of the selected track.
- The fold runs through the middle of the score. Notes on the crease stay tappable; no layout change is made for it in v1.

### Music engine

- **`crisp_notation_core` 0.13.x** (MIT, pure Dart) is the score model and the file codecs: it reads GP3–GP5, GPX, `.gp` (GPIF) and MusicXML/`.mxl`, and writes `.gp`, MusicXML and MIDI.
- **`crisp_notation` 0.13.x** (MIT) draws notation and tab with the bundled Bravura font, with per-element hit testing, repaint-only highlighting, loop bands and scroll-to-note.
- Both are young (one maintainer, about 1,000 downloads), so the first build step is a [spike](#step-0-spike) that decides whether they stay.
- Gaps found in them are fixed in a fork (both are MIT), with fixes offered upstream. A gap only triggers the spike's fallbacks when fixing it is a larger job than the fallback.
- **Guitar tracks**: a track counts as guitar when the file gives it strings and frets (a tab staff), or when its MIDI program is in the guitar family (25–32). A file with no guitar track plays its tracks and shows "This song has no guitar track".
- **Automatic fingering**: a guitar part with pitches but no string/fret data (common in MusicXML) gets strings and frets assigned on import, in standard tuning for its string count, preferring the lowest playable position and keeping consecutive notes close together. Retuning step 2 uses the same string-choice logic.

### Playback

- **Engine**: DuoTab writes a format-1 Standard MIDI File from `crisp_notation_core`'s `playbackTimeline`: one MIDI track per song track, the tempo map, velocities from dynamics, pitch bends for techniques. (`scoreToMidi` in `crisp_notation_core` writes format 0 with one tempo and velocity 80, which cannot carry these.) `AVAudioSequencer` plays it natively, with one `AVAudioUnitSampler` per track loaded from a bundled General MIDI SoundFont. A method channel exposes load, play, pause, seek, rate, loop range, mute/solo, program change, and an immediate single-note preview for editing. Dart polls the sequencer's position in beats to drive the cursor.
- **SoundFont**: a General MIDI `.sf2` with a licence that allows bundling (FluidR3_GM is the first candidate; the builder records the licence next to the file).
- **Tones** map to General MIDI programs (1-based): Clean = 28 Electric Guitar (clean), Overdrive = 30 Overdriven Guitar, High gain = 31 Distortion Guitar. A guitar track starts with its file's program when that is one of these three, otherwise Clean.
- **Practice settings** (tone, mute/solo, speed, loop) are kept by the app per file, outside the song file, so practising never modifies or copies a file. When the song is saved, each guitar track's tone is written as its MIDI program.
- **Other tracks** play with their file's program; drums play on MIDI channel 10 with the SoundFont's percussion bank.
- **Speed**: 25–150% of the written tempo, with 50/75/100% shortcuts. Tempo changes in the song are followed.
- **Looping**: drag across notes to set an A–B loop; on touch, long-press to start the selection.
- **Count-in** and **metronome** are toggles in Settings.
- **Techniques heard in MIDI**, at minimum: dynamics as velocity, bends and slides as pitch bend, vibrato, palm mute and dead notes as shortened, quieter notes, let ring as sustain, ghost notes as lower velocity.

### Editor

- **New song**: title, guitar with 6, 7 or 8 strings, tuning, tempo, starting time signature.
- **Guitar tracks**: a song can have several. The track panel adds, removes, renames and reorders them, and each has its own string count, tuning and tone. Non-guitar tracks from opened files are kept and played but cannot be edited.
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

- Songs live in the app's Documents folder, visible in the Files app under On My iPhone › DuoTab (`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`).
- The app registers document types for every supported extension, so Open In / AirDrop / Files offer DuoTab; an incoming file is copied into Documents.
- **Opened files are never overwritten.** The first edit to an opened file (any change to notes, bars, tracks or tuning) creates `<name> (DuoTab).gp` beside it, and autosave writes to that copy from then on. The library lists both. Songs created in the app save to `<title>.gp`.
- **Exports**, shared through the iOS share sheet: `.gp`, MusicXML, and PDF with title, tempo, tuning and notation over tab, paginated with `crisp_notation_core`'s page layout.

### Library screen

A list of the songs in Documents showing title, tuning and string count, and a **New song** button.

## Step 0: spike

A throwaway build, run before the plan's first real task, decides the music-engine and playback choices. It checks:

1. Guitar tracks of the [test files](#test-assets) render as notation over tab, with techniques visible.
2. A song created in code with 7 and 8 strings, mixed time signatures, a tempo change and four voices renders correctly.
3. That song saved as `.gp` opens in Guitar Pro 8 with nothing lost, voices 3 and 4 and the tunings included. The owner runs this check on their copy of Guitar Pro 8. `scoreToGpif` drops notes the tuning cannot reach, so the result also decides how retuning's unplayable notes are saved.
4. A MIDI file built from `playbackTimeline` plays through `AVAudioSequencer` with a SoundFont, in time, with a cursor that keeps up.
5. The spike report records the `crisp_notation_core` calls that give each imported track's name, tuning, string count, MIDI program and string/fret pins, which the import code depends on.

If 1 or 2 fails, rendering moves to a custom `CustomPainter` tab and notation renderer over the same model, or, as a last resort, alphaTab in a `WKWebView` (mature; renders and plays GP3–GP8 and MusicXML). If 3 fails, songs save in a DuoTab JSON format, MusicXML stays the interchange export, and `.gp` export waits until it works. If 4 fails, playback uses `dart_melty_soundfont` (pure Dart SoundFont synth) rendering PCM with sample-accurate event timing. MusicXML reading can fall back to `music_xml` 2.10.x (BSD).

## Test assets

- **Devices**: the iPhone Duo simulator in Xcode 27.1 is the default test target; the owner also has a physical iPhone Duo.
- **Guitar Pro 8**: the owner has it, for checking saved `.gp` files and comparing rendering.
- **Primary real-world file**: `/Users/eordonez/Desktop/07 Collateral Damage.xml`, a MusicXML 2.0 export from Guitar Pro 8.1.5. It has 7 guitar parts, all 6-string in E♭ standard, at 130 bpm. It has time signatures 2/4, 3/4, 3/8, 4/4, 5/8, 6/4 and 7/8, and hundreds of bends, hammer-ons, slides, vibratos, palm mutes, ties, tuplets, chords and dynamics. It has no second voices, no 7-string part and no tempo changes.
- **That file is a purchased Sheet Happens transcription** and must never be committed or bundled. Tests that use it read its path from an environment variable and skip when it is absent.
- **Gaps** (GP3, GP4, GP5, GPX and `.gp` binaries, several voices, 7- and 8-string, tempo changes): covered by files the owner exports from Guitar Pro 8 where it can, files the app writes itself, and open-source test corpora whose licence allows use as test fixtures.

## Left to the builder

- What the app does when the hinge status is unknown or the hierarchy has no hinge.
- The Split View width at which the side panels collapse.
- Exact panel widths, colours and typography, staying within the approved mockups.
- How each remaining technique is rendered in MIDI beyond the minimum list.
- Default fret count per string count, and the full tuning preset list beyond the minimum.
- Settings contents beyond count-in, metronome and default tone.
- Library sorting and search.

## Next phase (separate design)

Drum tracks drawn and edited as drum notation, with their own palette and input. The v1 model already records each track's instrument kind, so drums add a view and an editor without changing the model.

## References

- Inspiration: [tocarlagralla.cat](https://www.tocarlagralla.cat) (static web app: abcjs rendering, Web Audio sampler with look-ahead scheduling, A–B loop by dragging over notes, speed shortcuts, count-in).
- Apple: [Get ready for iPhone Duo](https://developer.apple.com/iphone-duo/), [Prepare](https://developer.apple.com/iphone-duo/prepare/), tech talks [111461](https://developer.apple.com/videos/play/tech-talks/111461/), [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111464](https://developer.apple.com/videos/play/tech-talks/111464/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/).
- Packages: [crisp_notation](https://pub.dev/packages/crisp_notation), [crisp_notation_core](https://pub.dev/packages/crisp_notation_core), [music_xml](https://pub.dev/packages/music_xml), [dart_melty_soundfont](https://pub.dev/packages/dart_melty_soundfont), [alphaTab](https://alphatab.net).
