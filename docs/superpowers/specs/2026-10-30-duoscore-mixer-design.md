# DuoScore Mixer: dB Faders, Meters, Pan and Master

**Status:** design, awaiting the owner's review.
**Extends:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`, Playback and the track drawer's Mixer.

## Why

Imported songs don't all play equally loud: GeneralUser GS plays some instruments far louder than others, though every track in the owner's 21 songs is stored at the same level. The owner balances tracks in Guitar Pro by watching its meters and moving dB faders, and wants the same in DuoScore. Placing guitars slightly left and right also sounds good on AirPods.

## Goals

1. Each track's volume is a **dB fader**, as in Guitar Pro, replacing the 0–100% slider.
2. Each track shows a **level meter**: its real level while the song plays.
3. Each track has a **pan knob**, from full left to full right.
4. A **Master** row at the bottom of the mixer, with its own fader and meter.
5. A song opens with the volume and pan **stored in its file**, so a Guitar Pro song sounds as its author mixed it.
6. The owner's changes **persist** between launches and are **written into the file** when the song is saved or exported.

## Non-goals

- Effects: EQ, reverb, delay, compression, amp models. Guitar Pro's master effects in the file are ignored.
- Drawing or editing volume and pan changes partway through a song. None of the owner's songs has any.
- A pan control on the Master row.

## Anti-goals

- Changing the mix alone must not create an edited copy of the song. It is practice, like tone, mute and solo.
- The meters must show the sound actually played. A level estimated from note velocities is not acceptable.
- Clipping. The output limiter (Plan 8) stays after the master fader.
- Stutter or glitches while dragging a fader or knob during playback.

## The owner's decisions

### Track row (mockup A, "like Guitar Pro")

One line per track, in this order: name, **M**, **S**, fader with the meter under it, dB readout, pan knob, **⋮**.

- **Fader:** −∞ at the left end, then −40 dB up to **+10 dB** at the right end, with **0 dB about four fifths of the way along**. A tick marks 0 dB.
- **Readout:** the fader's value, such as `−6.0 dB`, or `−∞ dB` when it's all the way down.
- **Meter:** two thin bars, left and right, under the fader. Blue, turning yellow and then red near the top. They fall to nothing when playback stops.
- **Pan knob:** full left to full right, centred by default.

### Master row

The last row of the mixer, labelled **Master**: a fader and readout with the same range as a track's, and a meter of the final output. There's no M, S or pan.

### Where the settings live

- **On first open,** each track's volume and pan come from the file, and the master volume too where the file has one (Guitar Pro 7/8 files do).
- **Changes** are kept per song in the practice settings, and survive relaunching.
- **On save or export** (the edited copy and `.gp` export), each track's volume and pan are written into the file.

## Calls I made (the owner can overrule)

- **Double-tap** a fader to set it to 0 dB, or the pan knob to centre it.
- **Fader law:** Guitar Pro's own. A track's fader position is its stored value, linear in dB from −40 dB at the left end to +10 dB at the right. A short stretch at the very left end is −∞.
- **Readout precision:** one decimal, in 0.5 dB steps while dragging. A value read from a file snaps to the nearest 0.5 dB, with ties toward 0 dB, so Guitar Pro's default 0.795 (−0.25 dB) reads 0.0 dB, as Guitar Pro shows it.
- **Pan:** shown as `L50`…`C`…`R50` beside the knob while it's turned, hidden otherwise. `L50` is full left, Guitar Pro's 0. A turned knob points in its direction. The pan law is the synth's own (constant power).
- **Meter scale:** the meter shares the fader's scale. A signal at 0 dBFS reaches the 0 dB tick, and −40 dBFS the −40 position. Yellow starts at −6 dBFS and red at −1 dBFS. The meter rises at once and falls at about 20 dB per second. There's no peak hold.
- **What a dB means:** a fader's dB is the track's real gain. 0 dB plays a track exactly as a Guitar Pro default-level track plays today (stored 0.795, MIDI volume 96), so the owner's songs sound unchanged until a fader moves. The same applies to Master at the 0.76 its files store.
- **Where the meters measure:** a track's meter shows what that track contributes to the output, after its fader and pan and including the engine's 2× output gain. The Master meter is measured after the master fader and the 2× gain, before the limiter. Both use one scale, so red on Master means the limiter is catching an overload.
- **Master** is kept per song in the practice settings and read from the file on first open. It isn't written into the file, because alphaTab's model has no master volume and its exporter writes its own.
- **When a mix change reaches a file:** the same as a tone change today. It's written when the song is next saved by an edit's autosave, and by Export of the open song. Sharing an unedited file from the library sends its bytes as they are.
- **Existing practice volumes** (0–16) convert to the dB that sounds the same as now. The synth cubes a level, so a track the file stores at `f` and the practice settings hold at `p` becomes `60·log10(p / f)` dB relative to the file's level. 12 of 12 (today's 75%) reads 0.0 dB.
- **Mute and solo** keep their current behaviour. A muted track's meter shows nothing.
- **A song's own mid-song volume or pan changes,** where a file has them, still play. The fader moves the whole track up or down by the difference from the file's level.
- **Where the mixer lives:** unchanged. The track drawer's Mixer toggle swaps the bar grid for these rows.

## Constraints (alphaTab 1.6.1 and the app as built)

- **File values:** Guitar Pro 7/8 store a track's volume and pan as fractions 0–1 in `ChannelStrip` parameters 12 and 11 (defaults 0.9 and 0.5), and the master's in `MasterTrack › RSE › Master › I01_VolumeAndPan` (*Parade of Rage*: tracks 0.795, master 0.76). alphaTab's importer floors the track values to 0–16 (`playbackInfo.volume`, `playbackInfo.balance`). That is too coarse for 0.5 dB steps, and it ignores the master. alphaTab's exporter writes `volume / 16` and `balance / 16` back.
- **Guitar Pro's mapping**, measured from a file the owner saved in Guitar Pro 8 (`~/Desktop/duoscore-compare/levels.gp`):
  - Track volume: `stored = (dB + 40) / 50`. +6 → 0.92, 0 → 0.80 (the default 0.795 shows as 0 dB), −6 → 0.68, −20 → 0.40.
  - Master volume: 0 dB → 0.76 and −6 dB → 0.61, so `stored = 0.76 + dB / 40`, clamped to 0–1. Only these two points are known.
  - Pan: 0 is full left, 0.5 centre, 1 full right.
  - Beside each track's `Parameters`, the file keeps `DSPParam_11` (pan) and `DSPParam_12` (volume) automations at bar 0. They kept the old values after the owner moved the faders. alphaTab reads only `Parameters`. A file DuoScore writes must keep the two consistent, so Guitar Pro doesn't play the old values.
- **Synth:** MIDI CC7 (with CC11) sets a channel's gain as `(CC7/127 · CC11/127)³`, with no headroom above CC7 = 127; `engine/src/mixer.ts` already accounts for the cube. A channel's mix volume (`channelSetMixVolume`, which the mixer already uses through `api.changeTrackVolume`) multiplies the gain with no upper bound, so +10 dB is possible. Pan is CC10 with a constant-power law. The player has no call to change pan during playback; the mixer rebuilds MIDI for changes it can't make live.
- **Meters:** alphaTab exposes no per-track levels. The synth mixes every track inside its web worker and posts one stereo stream to the page. The page sees the mixed stream at `api.player.output.addSamples`, where the limiter sits, which is enough for the Master meter. Per-track meters need per-channel measurement in the worker, for instance by serving a worker entry that wraps alphaTab's and reports levels per channel. That is the builder's choice, within the anti-goals.
- **The bridge** carries engine → app events as JSON; meter updates are a new event. The rate is the builder's, around 20–30 per second.
- **Two channels per track:** each track plays on a primary and a secondary channel. Level, pan and meters treat both as one track.

## What's left to the builder

- Fader and knob gestures, sizes and touch targets within mockup A, the meter's drawing, and the exact positions and colours.
- How per-track levels are measured and reported, and how often.
- How live changes reach the synth: mix volume where it can, rebuilding MIDI for pan, as the mixer does today.
- How file values are read at full precision.

## Acceptance

- *Parade of Rage* opens with all three guitars and the master at 0.0 dB, pan centred, as Guitar Pro shows it, and sounds as it does today.
- Dragging Guitar 2 to −6.0 dB during playback lowers it at once, with no glitch, and its meter drops by about 6 dB.
- Panning Guitar 1 to `L50` and Guitar 3 to `R50` moves them clearly apart on headphones.
- The changes survive closing and reopening the app. They're in the `.gp` file after saving, and opening that file in Guitar Pro shows the same pan and about the same volume.
- Changing only the mix creates no edited copy in the library.
- With the master fader at +10 dB on a loud passage, the Master meter shows red and the sound doesn't clip.
- Each track's meter moves only while that track plays, and shows nothing when the track is muted or soloed out.
