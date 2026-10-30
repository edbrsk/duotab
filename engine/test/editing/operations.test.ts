import * as alphaTab from '@coderline/alphatab';
import { beforeEach, expect, test } from 'vitest';

import { deleteNote, move, selectVoice, setDuration, setFret, setRest } from '../../src/editing/operations';
import type { EditPosition } from '../../src/protocol';
import { addGrace, setTuplet } from '../../src/editing/techniques';
import { fourQuarters, lineOfEighths, score, sixEight } from '../fixtures';

const at = (bar: number, beat: number, string = 1, voice = 0): EditPosition => ({ track: 0, bar, voice, beat, string });
let s: alphaTab.model.Score;
const voice = (bar: number, v = 0) => s.tracks[0].staves[0].bars[bar].voices[v];
const beat = (bar: number, b: number, v = 0) => voice(bar, v).beats[b];

beforeEach(() => {
  s = score(fourQuarters);
});

test('setFret puts a note on a rest', () => {
  setFret(s, at(0, 3, 2), 5);
  expect(beat(0, 3).isRest).toBe(false);
  expect(beat(0, 3).notes.map((n) => [n.string, n.fret])).toEqual([[2, 5]]);
});

test('setFret replaces the fret on a string that has a note', () => {
  setFret(s, at(0, 0, 1), 3);
  expect(beat(0, 0).notes.map((n) => [n.string, n.fret])).toEqual([[1, 3]]);
});

test('setFret adds a note on another string of the same beat', () => {
  setFret(s, at(0, 0, 3), 2);
  expect(beat(0, 0).notes.map((n) => [n.string, n.fret]).sort()).toEqual([
    [1, 0],
    [3, 2],
  ]);
});

test('deleting the only note leaves a rest', () => {
  deleteNote(s, at(0, 0, 1));
  expect(beat(0, 0).isRest).toBe(true);
});

test('setDuration changes the beat', () => {
  setDuration(s, at(0, 0), alphaTab.model.Duration.Eighth, 1);
  expect(beat(0, 0).duration).toBe(alphaTab.model.Duration.Eighth);
  expect(beat(0, 0).dots).toBe(1);
});

test("setRest clears the beat's notes", () => {
  setRest(s, at(0, 1));
  expect(beat(0, 1).isRest).toBe(true);
  expect(beat(0, 1).duration).toBe(alphaTab.model.Duration.Quarter);
});

test('moving right goes to the next beat, then the next bar', () => {
  expect(move(s, at(0, 2), 'right')).toEqual(at(0, 3));
  expect(move(s, at(0, 3), 'right')).toEqual(at(1, 0));
});

test('moving right from a bar that is not full adds a beat', () => {
  setDuration(s, at(0, 3), alphaTab.model.Duration.Eighth, 0);
  expect(move(s, at(0, 3), 'right')).toEqual(at(0, 4));
  expect(beat(0, 4).isRest).toBe(true);
  expect(beat(0, 4).duration).toBe(alphaTab.model.Duration.Eighth);
});

test('moving right from the last beat appends a bar', () => {
  expect(move(s, at(1, 0), 'right')).toEqual(at(2, 0));
  expect(s.masterBars).toHaveLength(3);
  expect([s.masterBars[2].timeSignatureNumerator, s.masterBars[2].timeSignatureDenominator]).toEqual([4, 4]);
  expect(voice(2).beats.map((b) => [b.isRest, b.duration])).toEqual([[true, alphaTab.model.Duration.Whole]]);
});

test('an appended bar is filled with rests that fit its time signature', () => {
  s = score(sixEight);
  move(s, at(0, 1), 'right');
  const rests = voice(1).beats;
  expect(rests.every((b) => b.isRest)).toBe(true);
  expect(rests.reduce((t, b) => t + b.playbackDuration, 0)).toBe(s.masterBars[1].calculateDuration());
});

test('moving up and down changes string within the track', () => {
  expect(move(s, at(0, 0, 1), 'up')).toEqual(at(0, 0, 2));
  expect(move(s, at(0, 0, 6), 'up')).toEqual(at(0, 0, 6));
  expect(move(s, at(0, 0, 2), 'down')).toEqual(at(0, 0, 1));
  expect(move(s, at(0, 0, 1), 'down')).toEqual(at(0, 0, 1));
});

test("moving left from the first beat goes to the previous bar's last beat", () => {
  expect(move(s, at(1, 0), 'left')).toEqual(at(0, 3));
  expect(move(s, at(0, 0), 'left')).toEqual(at(0, 0));
});

test('selectVoice creates an unused voice', () => {
  expect(selectVoice(s, at(0, 2), 1)).toEqual(at(0, 0, 1, 1));
  expect(s.tracks[0].staves[0].bars[0].voices).toHaveLength(2);
  expect(voice(0, 1).beats).toHaveLength(1);
  expect(voice(0, 1).beats[0].isEmpty).toBe(true);
});

test('a fret on an unused voice starts using it', () => {
  selectVoice(s, at(0, 0), 1);
  setFret(s, at(0, 0, 4, 1), 7);
  expect(beat(0, 0, 1).isEmpty).toBe(false);
  expect(beat(0, 0, 1).notes.map((n) => n.fret)).toEqual([7]);
});

test('frets outside 0-24 are refused', () => {
  expect(() => setFret(s, at(0, 0), 25)).toThrow('fret 25 out of range');
  expect(() => setFret(s, at(0, 0), -1)).toThrow('fret -1 out of range');
});

test('an appended bar has as many voices as the song uses', () => {
  selectVoice(s, at(0, 0), 1);
  move(s, at(1, 0), 'right');
  expect(s.tracks[0].staves[0].bars[2].voices).toHaveLength(2);
});

test('moving right in an unused voice turns its empty beat into a rest', () => {
  selectVoice(s, at(0, 0), 1);
  expect(move(s, at(0, 0, 1, 1), 'right')).toEqual(at(0, 1, 1, 1));
  expect(voice(0, 1).beats.map((b) => [b.isEmpty, b.isRest])).toEqual([
    [false, true],
    [false, true],
  ]);
});

test('deleting on a rest removes the beat', () => {
  expect(deleteNote(s, at(0, 3, 1))).toEqual(at(0, 2, 1));
  expect(voice(0).beats).toHaveLength(3);
  expect(voice(0).beats.map((b) => b.index)).toEqual([0, 1, 2]);
  expect(voice(0).beats[2].nextBeat).toBe(voice(1).beats[0]);
});

test('deleting the first beat keeps the cursor on the beat that moves in', () => {
  setRest(s, at(0, 0));
  expect(deleteNote(s, at(0, 0, 1))).toEqual(at(0, 0, 1));
  expect(beat(0, 0).notes.map((n) => [n.string, n.fret])).toEqual([[2, 2]]);
});

test("deleting a bar's last rest refills it with rests that fit", () => {
  setDuration(s, at(1, 0), alphaTab.model.Duration.Eighth, 0);
  expect(deleteNote(s, at(1, 0, 1))).toEqual(at(1, 0, 1));
  expect(voice(1).beats.map((b) => [b.isRest, b.duration])).toEqual([[true, alphaTab.model.Duration.Whole]]);
});

test("deleting a second voice's last rest makes the voice unused again", () => {
  selectVoice(s, at(0, 0), 1);
  move(s, at(0, 0, 1, 1), 'right');
  deleteNote(s, at(0, 1, 1, 1));
  deleteNote(s, at(0, 0, 1, 1));
  expect(voice(0, 1).beats.map((b) => b.isEmpty)).toEqual([true]);
});

test('deleting on a beat whose notes are on other strings changes nothing', () => {
  deleteNote(s, at(0, 0, 4));
  expect(beat(0, 0).notes.map((n) => [n.string, n.fret])).toEqual([[1, 0]]);
  expect(voice(0).beats).toHaveLength(4);
});

test('new beats, notes, voices and bars get ids no other object in the song has', () => {
  // Another import resets alphaTab's id counters, as the library's summaries do.
  score(sixEight);
  setDuration(s, at(0, 3), alphaTab.model.Duration.Eighth, 0);
  move(s, at(0, 3), 'right');
  setFret(s, at(0, 4, 2), 3);
  selectVoice(s, at(0, 0), 1);
  move(s, at(1, 0), 'right');
  const staff = s.tracks[0].staves[0];
  const unique = (ids: number[]) => expect(new Set(ids).size).toBe(ids.length);
  const voices = staff.bars.flatMap((b) => b.voices);
  const beats = voices.flatMap((v) => v.beats);
  unique(staff.bars.map((b) => b.id));
  unique(voices.map((v) => v.id));
  unique(beats.map((b) => b.id));
  unique(beats.flatMap((b) => b.notes.map((n) => n.id)));
});

test('deleting the only note of a grace beat removes the grace beat', () => {
  s = score(lineOfEighths);
  addGrace(s, at(0, 2, 4));
  expect(deleteNote(s, at(0, 2, 4))).toEqual(at(0, 2, 4));
  expect(voice(0).beats.map((b) => b.graceType)).toEqual([0, 0, 0, 0, 0, 0]);
  expect(voice(0).beats[2].notes.map((n) => n.fret)).toEqual([5]);
});

test('a grace note at the start of the next bar does not make this bar look short', () => {
  s = score(lineOfEighths);
  addGrace(s, at(1, 0, 1));
  expect(move(s, at(0, 5, 4), 'right')).toEqual(at(1, 0, 4));
});

test('a new beat continues the tuplet', () => {
  setDuration(s, at(1, 0), alphaTab.model.Duration.Eighth, 0);
  setTuplet(s, at(1, 0), 3);
  for (let b = 0; b < 11; b++) expect(move(s, at(1, b), 'right')).toEqual(at(1, b + 1));
  expect(voice(1).beats.every((b) => b.duration === 8 && b.tupletNumerator === 3 && b.tupletDenominator === 2)).toBe(true);
  // Twelve triplet eighths fill the 4/4 bar.
  expect(move(s, at(1, 11), 'right')).toEqual(at(2, 0));
});

test('an appended bar keeps the triplet feel', () => {
  s = score(sixEight);
  s.masterBars[0].tripletFeel = alphaTab.model.TripletFeel.Triplet8th;
  move(s, at(0, 1), 'right');
  expect(s.masterBars[1].tripletFeel).toBe(alphaTab.model.TripletFeel.Triplet8th);
});
