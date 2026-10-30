import * as alphaTab from '@coderline/alphatab';
import { beforeEach, expect, test } from 'vitest';

import { checkBars } from '../../src/editing/bar_check';
import { barProperties, setClef, setKeySignature, setTempo, setTimeSignature } from '../../src/editing/bars';
import type { EditPosition } from '../../src/protocol';
import { score, twoTracksThreeBars } from '../fixtures';

const at = (bar: number, beat = 0, string = 1, track = 0): EditPosition => ({ track, bar, voice: 0, beat, string });
let s: alphaTab.model.Score;
const signatures = () => s.masterBars.map((m) => `${m.timeSignatureNumerator}/${m.timeSignatureDenominator}`);
const bar = (track: number, index: number) => s.tracks[track].staves[0].bars[index];

beforeEach(() => {
  s = score(twoTracksThreeBars);
});

test('a time signature runs to the next change', () => {
  setTimeSignature(s, at(1), 3, 4);
  expect(signatures()).toEqual(['4/4', '3/4', '3/4']);
  s = score(twoTracksThreeBars);
  setTimeSignature(s, at(2), 6, 8);
  setTimeSignature(s, at(1), 3, 4);
  expect(signatures()).toEqual(['4/4', '3/4', '6/8']);
});

test('a time signature change keeps the notes and the bar check flags the bars', () => {
  setTimeSignature(s, at(0), 3, 4);
  expect(bar(0, 0).voices[0].beats.map((b) => b.notes.map((n) => n.fret))).toEqual([[0], [2], [3], [5]]);
  expect(checkBars(s, 0)).toEqual([{ bar: 0, voice: 0, ticksOff: 960 }]);
  expect(checkBars(s, 1)).toEqual([{ bar: 0, voice: 0, ticksOff: 960 }]);
});

test('bars of rests refill to the new time signature', () => {
  setTimeSignature(s, at(0), 3, 4);
  for (const track of [0, 1]) {
    for (const index of [1, 2]) {
      const beats = bar(track, index).voices[0].beats;
      expect(beats.every((b) => b.isRest)).toBe(true);
      expect(beats.reduce((t, b) => t + b.playbackDuration, 0)).toBe(2880);
    }
  }
});

test('a tempo marking sets that bar on', () => {
  setTempo(s, at(2), 140);
  expect(barProperties(s, at(2))).toMatchObject({ tempo: 140, tempoChange: true });
  expect(barProperties(s, at(1))).toMatchObject({ tempo: 100, tempoChange: false });
  setTempo(s, at(2), null);
  expect(barProperties(s, at(2))).toMatchObject({ tempo: 100, tempoChange: false });
  setTempo(s, at(0), 90);
  expect(s.tempo).toBe(90);
  expect(barProperties(s, at(0))).toMatchObject({ tempo: 90, tempoChange: true });
  setTempo(s, at(0), null);
  expect(barProperties(s, at(0))).toMatchObject({ tempo: 90, tempoChange: true });
});

test('a key signature goes on every track', () => {
  setKeySignature(s, at(1), -3, true);
  for (const track of [0, 1]) {
    expect([0, 1, 2].map((i) => [bar(track, i).keySignature, bar(track, i).keySignatureType])).toEqual([
      [0, alphaTab.model.KeySignatureType.Major],
      [-3, alphaTab.model.KeySignatureType.Minor],
      [-3, alphaTab.model.KeySignatureType.Minor],
    ]);
  }
  expect(barProperties(s, at(2))).toMatchObject({ key: -3, minor: true });
});

test('a clef goes on the cursor track only', () => {
  const before = [bar(1, 1).clef, bar(1, 1).clefOttava];
  setClef(s, at(1), 'bass');
  expect([1, 2].map((i) => [bar(0, i).clef, bar(0, i).clefOttava])).toEqual([
    [alphaTab.model.Clef.F4, alphaTab.model.Ottavia.Regular],
    [alphaTab.model.Clef.F4, alphaTab.model.Ottavia.Regular],
  ]);
  expect([bar(1, 1).clef, bar(1, 1).clefOttava]).toEqual(before);
  expect(barProperties(s, at(1)).clef).toBe('bass');
  expect(barProperties(s, at(0)).clef).toBe('treble');
});

test('out-of-range values are refused', () => {
  expect(() => setTimeSignature(s, at(0), 0, 4)).toThrow('time signature 0/4 out of range');
  expect(() => setTimeSignature(s, at(0), 4, 3)).toThrow('time signature 4/3 out of range');
  expect(() => setTimeSignature(s, at(0), 33, 4)).toThrow('time signature 33/4 out of range');
  expect(() => setTempo(s, at(0), 20)).toThrow('tempo 20 out of range');
  expect(() => setTempo(s, at(0), 301)).toThrow('tempo 301 out of range');
  expect(() => setKeySignature(s, at(0), 8, false)).toThrow('key signature 8 out of range');
});

test('bar properties survive the .gp round-trip', () => {
  setTimeSignature(s, at(2), 6, 8);
  setTempo(s, at(2), 140);
  setKeySignature(s, at(2), 2, false);
  setClef(s, at(2), 'treble');
  const settings = new alphaTab.Settings();
  const reloaded = alphaTab.importer.ScoreLoader.loadScoreFromBytes(
    new alphaTab.exporter.Gp7Exporter().export(s, settings),
    settings,
  );
  for (const index of [0, 1, 2]) expect(barProperties(reloaded, at(index))).toEqual(barProperties(s, at(index)));
});

test('a time signature change keeps the text and lyrics on its rests', () => {
  const s = score(String.raw`\track "G" \tuning E4 B3 G3 D3 A2 E2
r.4 r.4{txt "hello"} r.2`);
  s.tracks[0].staves[0].bars[0].voices[0].beats[2].lyrics = ['la'];
  setTimeSignature(s, { track: 0, bar: 0, voice: 0, beat: 0, string: 1 }, 3, 4);
  const beats = s.tracks[0].staves[0].bars[0].voices[0].beats;
  expect(beats.map((b) => b.text).filter(Boolean)).toEqual(['hello']);
  expect(beats.flatMap((b) => b.lyrics ?? [])).toEqual(['la']);
});
