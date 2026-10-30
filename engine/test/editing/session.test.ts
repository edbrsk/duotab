import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { setDuration } from '../../src/editing/operations';
import { EditSession } from '../../src/editing/session';
import { dStandardRiff, fourQuarters, guitarsAndDrums, lineOfEighths, score, sevenString, sixBars, twoGuitarsAndDrums, twoTracksThreeBars } from '../fixtures';

test("opening a song checks its bars and clears the cursor and history", async () => {
  const s = score(fourQuarters);
  setDuration(s, { track: 0, bar: 0, voice: 0, beat: 3, string: 1 }, alphaTab.model.Duration.Eighth, 0);
  const session = new EditSession();
  session.open(s, 0);
  expect(session.issues).toEqual([{ bar: 0, voice: 0, ticksOff: -480 }]);
  expect(session.position).toBeNull();
  expect(session.state(s, false).canUndo).toBe(false);
});

test('a track switch checks that track and clears the cursor', () => {
  const s = score(twoGuitarsAndDrums);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  session.drawTrack(s, 1);
  expect(session.position).toBeNull();
  expect(session.track).toBe(1);
});

test('commands need a placed cursor', () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  expect(() => session.command(s, { op: 'setFret', fret: 3 })).toThrow('no cursor');
});

test("the state tells the cursor beat's note value", () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 1, voice: 0, beat: 0, string: 1 } });
  expect(session.state(s, false).beat).toMatchObject({ duration: 1, dots: 0 });
});

test('an edit rechecks the bars', () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 3, string: 1 } });
  const { edited } = session.command(s, { op: 'setDuration', duration: 8, dots: 0 });
  expect(edited).toBe(true);
  expect(session.state(s, true).issues).toEqual([{ bar: 0, voice: 0, ticksOff: -480 }]);
});

test('the state lists the techniques at the cursor', () => {
  const s = score(lineOfEighths);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 4 } });
  session.command(s, { op: 'toggle', technique: 'palmMute' });
  expect(session.state(s, true).beat).toEqual({
    duration: 8,
    dots: 0,
    techniques: ['palmMute'],
    dynamic: 'f',
    tuplet: 1,
    hasNote: true,
    bend: null,
  });
  session.command(s, { op: 'setBend', bend: { kind: 'bendRelease', amount: 6 } });
  expect(session.state(s, true).beat?.bend).toEqual({ kind: 'bendRelease', amount: 6 });
  session.command(s, { op: 'move', direction: 'up' });
  expect(session.state(s, false).beat).toMatchObject({ techniques: [], hasNote: false });
});

test('the title changes without a cursor', () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  expect(session.command(s, { op: 'setTitle', title: 'Riff' })).toEqual({ edited: true });
  expect(session.position).toBeNull();
  expect(session.state(s, true).song.title).toBe('Riff');
});

test('the state tells the bar and whether paste can run', () => {
  const s = score(twoTracksThreeBars);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 1, voice: 0, beat: 0, string: 1 } });
  expect(session.state(s, false).bar).toEqual({
    numerator: 4,
    denominator: 4,
    key: 0,
    minor: false,
    clef: 'treble',
    tempo: 100,
    tempoChange: false,
  });
  expect(session.state(s, false).canPaste).toBe(false);
  expect(session.command(s, { op: 'copyBars' })).toEqual({ edited: false });
  expect(session.state(s, false).canPaste).toBe(true);
  expect(new EditSession().state(s, false).bar).toBeNull();
});

test("copy takes the loop's bars when the cursor is inside them", () => {
  const s = score(twoTracksThreeBars);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  session.command(s, { op: 'copyBars' }, { from: 0, to: 1 });
  session.command(s, { op: 'place', position: { track: 0, bar: 2, voice: 0, beat: 0, string: 1 } });
  expect(session.command(s, { op: 'pasteBars' })).toEqual({ edited: true });
  expect(s.masterBars).toHaveLength(4);
  expect(s.tracks[0].staves[0].bars[2].voices[0].beats.map((b) => b.notes[0]?.fret)).toEqual([0, 2, 3, 5]);
  session.command(s, { op: 'place', position: { track: 0, bar: 3, voice: 0, beat: 0, string: 1 } });
  session.command(s, { op: 'copyBars' }, { from: 0, to: 1 });
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  session.command(s, { op: 'pasteBars' });
  expect(s.masterBars).toHaveLength(4);
});

test("the state tells the bar's structure", () => {
  const s = score(sixBars);
  const session = new EditSession();
  session.open(s, 0);
  expect(session.state(s, false).structure).toBeNull();
  session.command(s, { op: 'place', position: { track: 0, bar: 2, voice: 0, beat: 0, string: 1 } });
  session.command(s, { op: 'setRepeatEnd', count: 2 });
  session.command(s, { op: 'toggleDirection', direction: 'fine' });
  expect(session.state(s, true).structure).toEqual({ repeatStart: false, repeatCount: 2, endings: [], directions: ['fine'] });
});

test('track commands need no cursor', () => {
  const s = score(guitarsAndDrums);
  const session = new EditSession();
  session.open(s, 0);
  expect(session.command(s, { op: 'addTrack', tuning: [64, 59, 55, 50, 45, 40], program: 27 })).toEqual({ edited: true });
  expect(session.state(s, true).drawnTrack).toBe(3);
  expect(session.position).toBeNull();
});

test('undoing a move keeps the drawn track and its cursor', async () => {
  const s = score(guitarsAndDrums);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  session.command(s, { op: 'moveTrack', track: 0, to: 1 });
  expect(session.track).toBe(1);
  const undone = (await session.history.undo(s))!;
  session.restored(undone, s);
  expect(session.track).toBe(0);
  expect(undone.tracks[0].name).toBe('Guitar A');
  expect(session.position?.track).toBe(0);
});

const E_STANDARD = [64, 59, 55, 50, 45, 40];

test('a retune reports its counts until the next edit', () => {
  const s = score(dStandardRiff);
  const session = new EditSession();
  session.open(s, 0);
  expect(session.command(s, { op: 'retune', track: 0, tuning: E_STANDARD, octave: 0 }).edited).toBe(true);
  expect(session.state(s, true).retune).toEqual({ track: 0, tuning: E_STANDARD, octave: 0, keep: 'pitch', moved: 1, unplayable: 1 });
  expect(session.marks.get(0)).toHaveLength(2);

  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  expect(session.state(s, false).retune).not.toBeNull();
  session.command(s, { op: 'setFret', fret: 5 });
  expect(session.state(s, true).retune).toBeNull();
  expect(session.marks.size).toBe(0);
});

test('a retune keeping frets reports so', () => {
  const s = score(sevenString);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'retune', track: 0, tuning: E_STANDARD, octave: 0, keep: 'frets' });
  expect(session.state(s, true).retune).toMatchObject({ keep: 'frets', moved: 1, unplayable: 0 });
});

test('undo clears the retune report and marks', async () => {
  const s = score(dStandardRiff);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'retune', track: 0, tuning: E_STANDARD, octave: 0 });
  const restored = (await session.history.undo(s))!;
  session.restored(restored, s);
  expect(session.state(restored, true).retune).toBeNull();
  expect(session.marks.size).toBe(0);
});

test('a retune to fewer strings keeps the cursor on a real string', () => {
  const s = score(sevenString);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 7 } });
  session.command(s, { op: 'retune', track: 0, tuning: E_STANDARD, octave: 0 });
  expect(session.position!.string).toBe(6);
  expect(session.position!.track).toBe(0);
});

test('a retune to more strings keeps the cursor on the same physical string', () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 6 } });
  session.command(s, { op: 'retune', track: 0, tuning: [64, 59, 55, 50, 45, 40, 35], octave: 0 });
  expect(session.position!.string).toBe(7);
});

test('two digits make one fret and one undo step', async () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 6 };
  session.command(s, { op: 'place', position: at });
  const before = alphaTab.model.JsonConverter.scoreToJson(s);
  session.command(s, { op: 'setFret', fret: 1 });
  session.command(s, { op: 'setFret', fret: 12, combine: true });
  const restored = await session.history.undo(s);
  expect(alphaTab.model.JsonConverter.scoreToJson(restored!)).toBe(before);
  expect(session.history.canUndo).toBe(false);
});

test('opening with fingering marks keeps them until the next edit', () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0, 'Edit', new Map([[0, [{ bar: 0, voice: 0, beat: 0, string: 6, kind: 'unplayable' as const }]]]));
  expect(session.marks.get(0)).toHaveLength(1);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  session.command(s, { op: 'setFret', fret: 5 });
  expect(session.marks.size).toBe(0);
});

test("a second digit without its first digit's step makes its own step", async () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 6 };
  session.command(s, { op: 'place', position: at });
  session.command(s, { op: 'setFret', fret: 1 });
  const atOne = alphaTab.model.JsonConverter.scoreToJson(s);
  // "1" again changes nothing, so it makes no step for "2" to join.
  session.command(s, { op: 'setFret', fret: 1 });
  session.command(s, { op: 'setFret', fret: 12, combine: true });
  const restored = await session.history.undo(s);
  expect(alphaTab.model.JsonConverter.scoreToJson(restored!)).toBe(atOne);
});

test('a second digit after an undo makes its own step', async () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 6 };
  session.command(s, { op: 'place', position: at });
  session.command(s, { op: 'setFret', fret: 1 });
  const restored = (await session.history.undo(s))!;
  session.restored(restored, s);
  session.command(restored, { op: 'place', position: at });
  session.command(restored, { op: 'setFret', fret: 12, combine: true });
  expect(session.history.canUndo).toBe(true);
  expect(session.history.canRedo).toBe(false);
});
