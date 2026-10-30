import * as alphaTab from '@coderline/alphatab';
import { beforeEach, expect, test } from 'vitest';

import { copyBars, deleteBar, insertBar, pasteBars } from '../../src/editing/bar_structure';
import { barProperties, setClef, setKeySignature, setTempo, setTimeSignature } from '../../src/editing/bars';
import { selectVoice, setFret } from '../../src/editing/operations';
import { toggleTechnique } from '../../src/editing/techniques';
import type { EditPosition } from '../../src/protocol';
import { playOrder, setEndings, setRepeatEnd, structureAt, toggleDirection, toggleRepeatStart } from '../../src/editing/structure';
import { score, sixBars, twoGuitarsAndDrums, twoTracksThreeBars } from '../fixtures';

const at = (bar: number, beat = 0, string = 1, track = 0, voice = 0): EditPosition => ({ track, bar, voice, beat, string });
let s: alphaTab.model.Score;
const bars = (track = 0) => s.tracks[track].staves[0].bars;
const frets = (track: number, bar: number) =>
  bars(track)[bar].voices[0].beats.map((b) => (b.isRest ? 'r' : b.notes.map((n) => `${n.string}/${n.fret}`).join('+')));
const unique = (values: number[]) => expect(new Set(values).size).toBe(values.length);
const expectUniqueIds = () => {
  const allBars = s.tracks.flatMap((t) => t.staves.flatMap((st) => st.bars));
  const voices = allBars.flatMap((b) => b.voices);
  const beats = voices.flatMap((v) => v.beats);
  unique(allBars.map((b) => b.id));
  unique(voices.map((v) => v.id));
  unique(beats.map((b) => b.id));
  unique(beats.flatMap((b) => b.notes.map((n) => n.id)));
};

beforeEach(() => {
  s = score(twoTracksThreeBars);
});

test('insert puts a bar of rests before the cursor bar', () => {
  expect(insertBar(s, at(0, 2, 3))).toEqual(at(0, 0, 3));
  expect(s.masterBars).toHaveLength(4);
  for (const track of [0, 1]) {
    expect(bars(track)).toHaveLength(4);
    expect(frets(track, 0)).toEqual(['r']);
    expect(frets(track, 1)).toEqual(['1/0', '1/2', '1/3', '1/5']);
  }
  expect(s.masterBars.map((m) => m.index)).toEqual([0, 1, 2, 3]);
  expectUniqueIds();
});

test("an inserted bar takes the cursor bar's time signature, key and clef", () => {
  setTimeSignature(s, at(1), 3, 4);
  setKeySignature(s, at(1), -2, false);
  setClef(s, at(1), 'bass');
  insertBar(s, at(1));
  expect(barProperties(s, at(1))).toMatchObject({ numerator: 3, denominator: 4, key: -2, clef: 'bass' });
  expect(bars()[1].voices[0].beats.reduce((t, b) => t + b.playbackDuration, 0)).toBe(2880);
});

test('inserting before the first bar takes over its tempo', () => {
  insertBar(s, at(0));
  expect(barProperties(s, at(0))).toMatchObject({ tempo: 100, tempoChange: true });
  expect(barProperties(s, at(1))).toMatchObject({ tempo: 100, tempoChange: false });
});

test('delete removes the bar from every track', () => {
  expect(deleteBar(s, at(0, 2))).toEqual(at(0));
  expect(s.masterBars).toHaveLength(2);
  for (const track of [0, 1]) expect(frets(track, 0)).toEqual(['r']);
  expect(deleteBar(s, at(1))).toEqual(at(0));
  expect(bars()[0].voices[0].beats.at(-1)!.nextBeat).toBeNull();
});

test('deleting a bar with a tempo change carries it to the next bar', () => {
  setTempo(s, at(1), 140);
  deleteBar(s, at(1));
  expect(barProperties(s, at(1))).toMatchObject({ tempo: 140, tempoChange: true });
  expect(barProperties(s, at(0))).toMatchObject({ tempo: 100 });
});

test('the only bar is never deleted', () => {
  deleteBar(s, at(2));
  deleteBar(s, at(1));
  expect(deleteBar(s, at(0))).toEqual(at(0));
  expect(s.masterBars).toHaveLength(1);
});

test('bar edits keep every track aligned and survive the .gp round-trip', () => {
  insertBar(s, at(1));
  deleteBar(s, at(0));
  insertBar(s, at(2));
  setFret(s, at(2, 0, 2), 7);
  expect(bars(0)).toHaveLength(bars(1).length);
  expectUniqueIds();
  const settings = new alphaTab.Settings();
  const reloaded = alphaTab.importer.ScoreLoader.loadScoreFromBytes(
    new alphaTab.exporter.Gp7Exporter().export(s, settings),
    settings,
  );
  const before = [0, 1].map((t) => bars(t).map((_, i) => frets(t, i)));
  s = reloaded;
  expect([0, 1].map((t) => bars(t).map((_, i) => frets(t, i)))).toEqual(before);
});

test('copy and paste repeat bars', () => {
  toggleTechnique(s, at(0, 0), 'palmMute');
  toggleTechnique(s, at(0, 1), 'bend');
  pasteBars(s, at(2), copyBars(s, 0, 0, 0));
  expect(frets(0, 2)).toEqual(frets(0, 0));
  const pasted = bars()[2].voices[0].beats;
  expect(pasted[0].notes[0].isPalmMute).toBe(true);
  expect(pasted[1].notes[0].hasBend).toBe(true);
  expect(frets(0, 0)).toEqual(['1/0', '1/2', '1/3', '1/5']);
  expect(frets(1, 2)).toEqual(['r']);
  expectUniqueIds();
});

test('paste past the end adds bars', () => {
  expect(pasteBars(s, at(2), copyBars(s, 0, 0, 1))).toEqual(at(2));
  expect(s.masterBars).toHaveLength(4);
  expect(bars(1)).toHaveLength(4);
  expect(frets(0, 3)).toEqual(['r']);
  expectUniqueIds();
});

test('paste drops notes on strings the track lacks', () => {
  const seven = score(twoGuitarsAndDrums);
  setFret(seven, at(0, 0, 7, 1), 3);
  const clipboard = copyBars(seven, 1, 0, 0);
  pasteBars(s, at(1), clipboard);
  expect(frets(0, 1)).toEqual(['1/0']);
});

test("paste keeps the staff's voice counts equal", () => {
  selectVoice(s, at(0), 1);
  setFret(s, at(0, 0, 2, 0, 1), 4);
  const clipboard = copyBars(s, 0, 0, 0);
  s = score(twoTracksThreeBars);
  pasteBars(s, at(1), clipboard);
  expect(bars().map((b) => b.voices.length)).toEqual([2, 2, 2]);
  expect(bars()[1].voices[1].beats[0].notes.map((n) => n.fret)).toEqual([4]);
  expectUniqueIds();
});

test('the clipboard survives another song', () => {
  const clipboard = copyBars(s, 0, 0, 0);
  s = score(twoTracksThreeBars);
  pasteBars(s, at(2, 0, 1, 1), clipboard);
  expect(frets(1, 2)).toEqual(['1/0', '1/2', '1/3', '1/5']);
});

const linked = (bars: string) => score(String.raw`\title "Links"
.
\track "A" \tuning E4 B3 G3 D3 A2 E2
r.1 | r.1 | r.1
\track "B" \tuning E4 B3 G3 D3 A2 E2
${bars}`);

test('bars that start with a tie, slide or hammer-on from the bar before paste', () => {
  for (const content of ['3.6.1 | -.6.1 | r.1', '3.6{sl}.1 | 5.6.1 | r.1', '3.6{h}.1 | 5.6.1 | r.1']) {
    s = linked(content);
    const clipboard = copyBars(s, 1, 1, 1);
    expect(() => pasteBars(s, at(2, 0, 1, 1), clipboard), content).not.toThrow();
    expect(bars(1)[2].voices[0].beats[0].notes, content).toHaveLength(1);
  }
});

test('insert and delete relink ties in the other tracks', () => {
  s = linked('3.6.1 | -.6.1 | 5.6.1');
  deleteBar(s, at(0));
  const note = bars(1)[0].voices[0].beats[0].notes[0];
  expect(note.tieOrigin).toBeNull();
  expect(note.isTieDestination).toBe(false);
});

test('pasted chord names come with their chords', () => {
  const chord = new alphaTab.model.Chord();
  chord.name = 'C';
  chord.strings = [0, 1, 0, 2, 3, -1];
  bars(0)[0].staff.addChord('c0', chord);
  bars(0)[0].voices[0].beats[0].chordId = 'c0';
  s.finish(new alphaTab.Settings());
  const clipboard = copyBars(s, 0, 0, 0);
  pasteBars(s, at(2, 0, 1, 1), clipboard);
  expect(bars(1)[2].voices[0].beats[0].chord?.name).toBe('C');
});

test('an inserted bar keeps the triplet feel', () => {
  for (const m of s.masterBars) m.tripletFeel = alphaTab.model.TripletFeel.Triplet8th;
  insertBar(s, at(1));
  expect(s.masterBars.map((m) => m.tripletFeel)).toEqual(Array(4).fill(alphaTab.model.TripletFeel.Triplet8th));
});

const section = (marker: string) => {
  const value = new alphaTab.model.Section();
  value.marker = marker;
  value.text = marker;
  return value;
};

test("deleting the bars at a repeat's edges keeps the repeat", () => {
  s = score(sixBars);
  toggleRepeatStart(s, at(1));
  setRepeatEnd(s, at(3), 2);
  deleteBar(s, at(1));
  expect(structureAt(s, at(1)).repeatStart).toBe(true);
  expect(playOrder(s)).toEqual([0, 1, 2, 1, 2, 3, 4]);
  s = score(sixBars);
  toggleRepeatStart(s, at(1));
  setRepeatEnd(s, at(3), 2);
  deleteBar(s, at(3));
  expect(structureAt(s, at(2)).repeatCount).toBe(2);
  expect(playOrder(s)).toEqual([0, 1, 2, 1, 2, 3, 4]);
});

test('a one-bar repeat goes with its bar', () => {
  s = score(sixBars);
  toggleRepeatStart(s, at(2));
  setRepeatEnd(s, at(2), 2);
  deleteBar(s, at(2));
  expect(s.masterBars.map((_, i) => structureAt(s, at(i))).some((x) => x.repeatStart || x.repeatCount)).toBe(false);
});

test('deleting a bar keeps its marks', () => {
  s = score(sixBars);
  toggleDirection(s, at(2), 'segno');
  s.masterBars[2].section = section('A');
  toggleDirection(s, at(4), 'dalSegno');
  deleteBar(s, at(2));
  expect(structureAt(s, at(2)).directions).toEqual(['segno']);
  expect(s.masterBars[2].section?.marker).toBe('A');
  deleteBar(s, at(3));
  expect(structureAt(s, at(2)).directions).toEqual(['segno', 'dalSegno']);
});

test('a carried mark never replaces one already there', () => {
  s = score(sixBars);
  s.masterBars[2].section = section('A');
  s.masterBars[3].section = section('B');
  toggleDirection(s, at(3), 'daCapo');
  toggleDirection(s, at(4), 'dalSegno');
  deleteBar(s, at(2));
  expect(s.masterBars[2].section?.marker).toBe('B');
  deleteBar(s, at(3));
  expect(structureAt(s, at(2)).directions).toEqual(['daCapo']);
});

test('a bar inserted inside an ending joins it', () => {
  s = score(sixBars);
  setEndings(s, at(2), [1]);
  setEndings(s, at(3), [1]);
  insertBar(s, at(3));
  expect(structureAt(s, at(3)).endings).toEqual([1]);
  insertBar(s, at(2));
  expect(structureAt(s, at(2)).endings).toEqual([]);
});

test('an inserted bar takes no repeat or direction', () => {
  s = score(sixBars);
  toggleRepeatStart(s, at(2));
  toggleDirection(s, at(2), 'segno');
  insertBar(s, at(2));
  expect(structureAt(s, at(2))).toEqual({ repeatStart: false, repeatCount: 0, endings: [], directions: [] });
  expect(structureAt(s, at(3))).toMatchObject({ repeatStart: true, directions: ['segno'] });
});
