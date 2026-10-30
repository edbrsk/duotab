import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { playEffectsUnderTremolo } from '../src/midi_effects';
import { score } from './fixtures';

// A subclass, so alphaTab's own generator stays for comparison.
class Fixed extends alphaTab.midi.MidiFileGenerator {}
playEffectsUnderTremolo(Fixed);

const BAR = 3840;

// Parade of Rage's Guitar 2: the 12th fret held across four bars, diving an
// octave (whammy values are quarter tones).
function dive(tremolo: boolean): alphaTab.model.Score {
  const s = score(String.raw`\title "Dive"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
12.6.1 | -.6.1 | -.6.1 | -.6.1`);
  const values = [
    [0, -4],
    [-4, -14],
    [-14, -24],
    [-24, -24],
  ];
  s.tracks[0].staves[0].bars.forEach((bar, i) => {
    const beat = bar.voices[0].beats[0];
    beat.whammyBarType = i === 3 ? alphaTab.model.WhammyType.Hold : alphaTab.model.WhammyType.Dive;
    beat.whammyBarPoints = [];
    beat.addWhammyBarPoint(new alphaTab.model.BendPoint(0, values[i][0]));
    beat.addWhammyBarPoint(new alphaTab.model.BendPoint(alphaTab.model.BendPoint.MaxPosition, values[i][1]));
    if (tremolo) beat.tremoloSpeed = alphaTab.model.Duration.Eighth;
  });
  s.finish(new alphaTab.Settings());
  return s;
}

function midiOf(s: alphaTab.model.Score, generator: typeof alphaTab.midi.MidiFileGenerator = Fixed) {
  const midi = new alphaTab.midi.MidiFile();
  new generator(s, new alphaTab.Settings(), new alphaTab.midi.AlphaSynthMidiFileHandler(midi)).generate();
  return midi.tracks.flatMap((t) => t.events);
}

/**
 * The semitones the synth plays the sounding note at, every `step` ticks: it
 * adds the channel's pitch wheel to the note's own, and a note-off clears the
 * note's own (alphaTab 1.6.1 TinySoundFont).
 */
function pitchCurve(s: alphaTab.model.Score, end: number, step = 120): (number | null)[] {
  const events = midiOf(s);
  let range = 2;
  let wheel = 8192;
  const own = new Map<number, number>();
  const sounding = new Set<number>();
  const curve: (number | null)[] = [];
  let i = 0;
  for (let tick = 0; tick < end; tick += step) {
    for (; i < events.length && events[i].tick <= tick; i++) {
      const e = events[i];
      if (e instanceof alphaTab.midi.ControlChangeEvent && e.controller === 6) range = e.value;
      else if (e instanceof alphaTab.midi.PitchBendEvent) wheel = e.value;
      else if (e instanceof alphaTab.midi.NoteBendEvent) own.set(e.noteKey, (e.value / 2 ** 32) * 16384);
      else if (e instanceof alphaTab.midi.NoteOnEvent) sounding.add(e.noteKey);
      else if (e instanceof alphaTab.midi.NoteOffEvent) {
        sounding.delete(e.noteKey);
        own.delete(e.noteKey);
      }
    }
    const [key] = sounding;
    curve.push(key === undefined ? null : ((wheel - 8192 + (own.get(key) ?? 8192) - 8192) / 8192) * range);
  }
  return curve;
}

const atTick = (curve: (number | null)[], tick: number) => curve[tick / 120];

test('a tremolo-picked dive falls smoothly to an octave down', () => {
  const curve = pitchCurve(dive(true), 4 * BAR);
  expect(atTick(curve, 0)).toBeCloseTo(0, 1);
  for (let i = 1; i < (3 * BAR) / 120; i++) expect(curve[i]!).toBeLessThanOrEqual(curve[i - 1]! + 1e-9);
  expect(atTick(curve, 3 * BAR - 120)).toBeCloseTo(-12, 0);
  for (const p of curve.slice((3 * BAR) / 120)) expect(p).toBeCloseTo(-12, 1);
});

test('a dive continued on tied notes is applied once', () => {
  const curve = pitchCurve(dive(false), 4 * BAR);
  expect(atTick(curve, BAR)).toBeCloseTo(-2, 1);
  expect(atTick(curve, 2 * BAR)).toBeCloseTo(-7, 1);
  for (const p of curve.slice((3 * BAR) / 120)) expect(p).toBeCloseTo(-12, 1);
});

test('a tremolo-picked bend keeps its pitch on every re-strike', () => {
  const s = score(String.raw`\title "Bend"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
7.3.1`);
  const note = s.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0];
  note.beat.tremoloSpeed = alphaTab.model.Duration.Eighth;
  note.bendType = alphaTab.model.BendType.Custom;
  note.addBendPoint(new alphaTab.model.BendPoint(0, 0));
  note.addBendPoint(new alphaTab.model.BendPoint(15, 4));
  note.addBendPoint(new alphaTab.model.BendPoint(alphaTab.model.BendPoint.MaxPosition, 4));
  s.finish(new alphaTab.Settings());
  const curve = pitchCurve(s, BAR);
  for (const p of curve.slice(BAR / 2 / 120)) expect(p).toBeCloseTo(2, 1);
});

test('tremolo picking still strikes the note on every eighth', () => {
  const s = dive(true);
  const strikes = midiOf(s).filter((e) => e instanceof alphaTab.midi.NoteOnEvent && e.tick < BAR);
  expect(strikes.map((e) => e.tick)).toEqual([0, 480, 960, 1440, 1920, 2400, 2880, 3360]);
});

test('a note without tremolo or whammy plays as alphaTab makes it', () => {
  const plain = () =>
    score(String.raw`\title "Plain"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
5.3{v}.4 7.3{b (0 4)}.4 9.3{sl}.4 7.3.4`);
  const lines = (generator: typeof alphaTab.midi.MidiFileGenerator) =>
    midiOf(plain(), generator).map((e) => `${e.tick} ${e.constructor.name} ${JSON.stringify(e)}`);
  expect(lines(Fixed)).toEqual(lines(alphaTab.midi.MidiFileGenerator));
});

test('a note after a dive starts at its own pitch', () => {
  // As the dive's section repeats: a fresh note, tied into the next dive.
  const s = score(String.raw`\title "Again"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
12.6.1 | 12.6.2 -.6.2`);
  const [first, second] = s.tracks[0].staves[0].bars;
  const whammy = (beat: alphaTab.model.Beat, from: number, to: number) => {
    beat.whammyBarType = alphaTab.model.WhammyType.Dive;
    beat.addWhammyBarPoint(new alphaTab.model.BendPoint(0, from));
    beat.addWhammyBarPoint(new alphaTab.model.BendPoint(alphaTab.model.BendPoint.MaxPosition, to));
  };
  whammy(first.voices[0].beats[0], 0, -24);
  whammy(second.voices[0].beats[1], 0, -4);
  s.finish(new alphaTab.Settings());
  const curve = pitchCurve(s, 2 * BAR);
  for (const p of curve.slice(BAR / 120, (BAR + BAR / 2) / 120)) expect(p).toBeCloseTo(0, 1);
});

test('tied tremolo-picked notes strike once on every eighth', () => {
  const strikes = midiOf(dive(true))
    .filter((e) => e instanceof alphaTab.midi.NoteOnEvent)
    .map((e) => e.tick);
  expect(strikes).toEqual(Array.from({ length: 32 }, (_, i) => i * 480));
});
