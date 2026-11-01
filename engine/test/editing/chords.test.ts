import * as alphaTab from '@coderline/alphatab';
import { beforeEach, expect, test } from 'vitest';

import { setChord } from '../../src/editing/chords';
import { runCommand } from '../../src/editing/commands';
import { History } from '../../src/editing/history';
import { deleteNote, setFret, setRest } from '../../src/editing/operations';
import { EditSession } from '../../src/editing/session';
import type { ChordSpec, EditPosition } from '../../src/protocol';
import { fourQuarters, score } from '../fixtures';

const at = (bar: number, beat: number, string = 1, voice = 0): EditPosition => ({ track: 0, bar, voice, beat, string });
const cmaj7: ChordSpec = { root: 0, type: 'maj7', additions: [], bass: null };
const OPEN = [-1, 3, 2, 0, 0, 0];
const BARRE = [-1, 3, 5, 4, 5, 3];
let s: alphaTab.model.Score;
const beat = (bar: number, b: number, v = 0) => s.tracks[0].staves[0].bars[bar].voices[v].beats[b];
const pairs = (b: alphaTab.model.Beat) => b.notes.map((n) => [n.string, n.fret]).sort((x, y) => x[0] - y[0]);

beforeEach(() => {
  s = score(fourQuarters);
});

test('writing Cmaj7 puts its notes and name on the beat', () => {
  expect(setChord(s, at(0, 1), cmaj7, OPEN)).toEqual(at(0, 1));
  expect(pairs(beat(0, 1))).toEqual([
    [2, 3],
    [3, 2],
    [4, 0],
    [5, 0],
    [6, 0],
  ]);
  expect(beat(0, 1).chord!.name).toBe('Cmaj7');
  expect(beat(0, 1).chord!.strings).toEqual([0, 0, 0, 2, 3, -1]);
  expect(beat(0, 1).chord!.showDiagram).toBe(false);
});

test('a chord replaces the beat’s notes and touches nothing else', () => {
  const first = pairs(beat(0, 0));
  setFret(s, at(0, 1, 1), 7);
  setChord(s, at(0, 1), cmaj7, OPEN);
  expect(pairs(beat(0, 0))).toEqual(first);
  expect(pairs(beat(0, 1)).map(([string]) => string)).toEqual([2, 3, 4, 5, 6]);
});

test('a chord in another voice leaves the first voice alone', () => {
  const before = s.tracks[0].staves[0].bars[0].voices[0].beats.map(pairs);
  runCommand(s, at(0, 0), { op: 'selectVoice', voice: 1 }, new History());
  setChord(s, at(0, 0, 1, 1), cmaj7, OPEN);
  expect(s.tracks[0].staves[0].bars[0].voices[0].beats.map(pairs)).toEqual(before);
  expect(beat(0, 0, 1).chord!.name).toBe('Cmaj7');
});

test("a frets list that isn't one of the chord's positions is refused", () => {
  expect(() => setChord(s, at(0, 1), cmaj7, [-1, 3, 3, 0, 0, 0])).toThrow('not a position of this chord');
});

test('undo removes the chord and redo brings it back', async () => {
  const history = new History();
  runCommand(s, at(0, 1), { op: 'setChord', chord: cmaj7, frets: OPEN }, history);
  const undone = (await history.undo(s))!;
  const was = undone.tracks[0].staves[0].bars[0].voices[0].beats[1];
  expect(was.chordId).toBeNull();
  expect(pairs(was)).toEqual([[2, 2]]);
  const redone = (await history.redo(undone))!;
  const again = redone.tracks[0].staves[0].bars[0].voices[0].beats[1];
  expect(again.chord!.name).toBe('Cmaj7');
  expect(pairs(again)).toHaveLength(5);
});

test('rewriting with another position or another name counts as an edit', () => {
  const history = new History();
  runCommand(s, at(0, 1), { op: 'setChord', chord: cmaj7, frets: OPEN }, history);
  expect(runCommand(s, at(0, 1), { op: 'setChord', chord: cmaj7, frets: BARRE }, history).edited).toBe(true);
  runCommand(s, at(0, 1), { op: 'setChord', chord: cmaj7, frets: OPEN }, history);
  const emOverC: ChordSpec = { root: 4, type: 'm', additions: [], bass: 0 };
  const renamed = runCommand(s, at(0, 1), { op: 'setChord', chord: emOverC, frets: OPEN }, history);
  expect(renamed.edited).toBe(true);
  expect(beat(0, 1).chord!.name).toBe('Em/C');
});

test('editing one of its notes keeps the name', () => {
  setChord(s, at(0, 1), cmaj7, OPEN);
  const id = beat(0, 1).chordId;
  setFret(s, at(0, 1, 2), 5);
  expect(beat(0, 1).chordId).toBe(id);
});

test("deleting a chord's last note drops its name", () => {
  setChord(s, at(0, 1), cmaj7, OPEN);
  setRest(s, at(0, 1));
  expect(beat(0, 1).chordId).toBeNull();

  setChord(s, at(0, 2), cmaj7, OPEN);
  for (const string of [2, 3, 4, 5, 6]) {
    expect(beat(0, 2).chordId).not.toBeNull();
    deleteNote(s, at(0, 2, string));
  }
  expect(beat(0, 2).chordId).toBeNull();
});

test('the cursor beat reports its chord and frets', () => {
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: at(0, 1) });
  session.command(s, { op: 'setChord', chord: cmaj7, frets: OPEN });
  const reported = session.state(s, true).beat!;
  expect(reported.chord).toEqual({ name: 'Cmaj7', spec: cmaj7 });
  expect(reported.frets).toEqual(OPEN);

  beat(0, 1).chord!.name = 'N.C.';
  expect(session.state(s, false).beat!.chord).toEqual({ name: 'N.C.', spec: null });

  session.command(s, { op: 'place', position: at(0, 0) });
  expect(session.state(s, false).beat!.chord).toBeNull();
});

test('Guitar Pro keeps the chord', () => {
  setChord(s, at(0, 1), cmaj7, OPEN);
  const bytes = new alphaTab.exporter.Gp7Exporter().export(s, new alphaTab.Settings());
  const back = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, new alphaTab.Settings());
  const reloaded = back.tracks[0].staves[0].bars[0].voices[0].beats[1];
  expect(reloaded.chord!.name).toBe('Cmaj7');
  expect(pairs(reloaded)).toEqual(pairs(beat(0, 1)));
});

test("positions follow the drawn track's own strings", async () => {
  const { twoGuitarsAndDrums } = await import('../fixtures');
  const song = score(twoGuitarsAndDrums);
  const session = new EditSession();
  session.open(song, 1);
  const reply = session.chordPositions(song, cmaj7);
  expect(reply.name).toBe('Cmaj7');
  expect(reply.positions.length).toBeGreaterThan(0);
  for (const p of reply.positions) expect(p.frets).toHaveLength(7);
});
