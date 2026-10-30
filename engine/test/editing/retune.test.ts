import { readFileSync } from 'node:fs';

import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { runCommand } from '../../src/editing/commands';
import { History } from '../../src/editing/history';
import { retune } from '../../src/editing/retune';
import { dStandardLegato, dStandardRiff, score, sevenString } from '../fixtures';

const E = [64, 59, 55, 50, 45, 40];
const D = [62, 57, 53, 48, 43, 38];

const notes = (song: alphaTab.model.Score) =>
  song.tracks[0].staves[0].bars.flatMap((bar) => bar.voices.flatMap((v) => v.beats.flatMap((b) => b.notes)));
const placed = (song: alphaTab.model.Score, bar: number) =>
  song.tracks[0].staves[0].bars[bar].voices[0].beats.map((b) => b.notes.map((n) => `${n.string}/${n.fret}`).sort());

test('retuning keeps each pitch and moves the frets', () => {
  const song = score(dStandardRiff);
  const before = notes(song).map((n) => n.realValue);
  retune(song, 0, E, 0);
  expect(song.tracks[0].staves[0].tuning).toEqual(E);
  expect(placed(song, 0).slice(0, 2)).toEqual([['1/0'], ['2/2']]);
  const after = notes(song).map((n) => n.realValue);
  // The open low D has no string in E standard.
  expect(after.filter((v, i) => v !== before[i])).toEqual([40]);
});

test('a note out of range moves to a free string', () => {
  const song = score(dStandardRiff);
  const marks = retune(song, 0, E, 0);
  expect(placed(song, 0)[2]).toEqual(['3/1', '4/3']);
  expect(marks).toContainEqual({ bar: 0, voice: 0, beat: 2, string: 4, kind: 'moved' });
});

test('a note no string can play keeps its fret and is marked', () => {
  const song = score(dStandardRiff);
  const marks = retune(song, 0, E, 0);
  expect(placed(song, 0)[3]).toEqual(['1/0']);
  expect(marks).toContainEqual({ bar: 0, voice: 0, beat: 3, string: 1, kind: 'unplayable' });
  expect(marks).toHaveLength(2);
});

test('a hammer-on moves with its partner', () => {
  const song = score(dStandardLegato);
  retune(song, 0, E, 0);
  expect(placed(song, 0)).toEqual([['1/4'], ['1/6']]);
  expect(song.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0].isHammerPullOrigin).toBe(true);
  expect(song.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0].hammerPullDestination).not.toBeNull();
});

test("a group that can't stay together loses its link", () => {
  const song = score(dStandardLegato);
  const marks = retune(song, 0, E, 0);
  expect(placed(song, 1)).toEqual([['1/4'], ['2/22']]);
  expect(song.tracks[0].staves[0].bars[1].voices[0].beats[0].notes[0].isHammerPullOrigin).toBe(false);
  expect(marks.filter((m) => m.bar === 1)).toEqual([{ bar: 1, voice: 0, beat: 0, string: 1, kind: 'moved' }]);
});

test('an unplayable note never shares a string with another note of its beat', () => {
  // In E standard both E♭2+3 and A♭2 need the low E string.
  const song = score(String.raw`\track "G" \tuning Eb4 Bb3 Gb3 Db3 Ab2 Eb2
(3.6 0.4 0.3 3.2 0.5).1`);
  const marks = retune(song, 0, E, 0);
  const strings = song.tracks[0].staves[0].bars[0].voices[0].beats[0].notes.map((n) => n.string);
  expect(new Set(strings).size).toBe(5);
  expect(marks.filter((m) => m.kind === 'unplayable')).toHaveLength(1);
});

test('natural harmonics keep their pitch or are marked', () => {
  const song = score(String.raw`\track "G" \tuning D4 A3 F3 C3 G2 D2
12.6{nh}.4 7.5{nh}.4 5.4{nh}.4 12.3{nh}.4`);
  const before = notes(song).map((n) => n.realValue);
  const marks = retune(song, 0, E, 0);
  const unplayable = marks.filter((m) => m.kind === 'unplayable');
  for (const [i, note] of notes(song).entries()) {
    const marked = unplayable.some((m) => m.beat === note.beat.index && m.string === note.string);
    if (!marked) expect(note.realValue).toBe(before[i]);
  }
});

test('a natural harmonic moves to a string where its node sounds the same', () => {
  // A3's 12th-fret harmonic, A4, is no node of B3 but the 7th of D3 and the 5th of A2.
  const song = score(String.raw`\track "G" \tuning D4 A3 F3 C3 G2 D2
12.2{nh}.1`);
  const before = notes(song)[0].realValue;
  const marks = retune(song, 0, E, 0);
  expect(notes(song)[0].realValue).toBe(before);
  expect(marks).toEqual([{ bar: 0, voice: 0, beat: 0, string: notes(song)[0].string, kind: 'moved' }]);
});

test('a moved note never takes over a tie that spans its beat', () => {
  const song = score(String.raw`\track "G" \tuning D4 A3 F3 C3 G2 D2
3.6.8 0.5.8 -.6.8 0.4.8 r.2`);
  const before = notes(song).map((n) => n.realValue);
  retune(song, 0, E, 0);
  const tied = song.tracks[0].staves[0].bars[0].voices[0].beats[2].notes[0];
  expect(tied.tieOrigin).toBe(song.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0]);
  expect(tied.realValue).toBe(before[2]);
});

test("a retune leaves no note findable on a string it left", () => {
  const song = score(dStandardLegato);
  retune(song, 0, E, 0);
  const beat = song.tracks[0].staves[0].bars[0].voices[0].beats[0];
  expect(beat.notes[0].string).toBe(1);
  expect(beat.getNoteOnString(2)).toBeNull();
});

test('fewer strings map from the top', () => {
  const song = score(sevenString);
  const marks = retune(song, 0, E, 0);
  expect(song.tracks[0].staves[0].tuning).toEqual(E);
  expect(placed(song, 0)).toEqual([['1/0'], ['6/5']]);
  expect(marks).toEqual([{ bar: 0, voice: 0, beat: 0, string: 1, kind: 'unplayable' }]);
});

test('an octave shifts every pitch', () => {
  const song = score(dStandardRiff);
  const before = notes(song).map((n) => n.realValue);
  const marks = retune(song, 0, D, 1);
  expect(marks).toEqual([]);
  expect(notes(song).map((n) => n.realValue)).toEqual(before.map((v) => v + 12));
});

test('chord diagrams follow the retune', () => {
  const song = score(dStandardRiff);
  retune(song, 0, E, 0);
  const chords = song.tracks[0].staves[0].chords!;
  expect(chords.get('high00')!.strings).toEqual([3, 3, 3, -1, -1, -1]);
  expect(chords.get('high00')!.showDiagram).toBe(true);
  expect(chords.get('low00')!.showDiagram).toBe(false);
});

test('the tuning name follows the new tuning', () => {
  const song = score(dStandardRiff);
  retune(song, 0, E, 0);
  expect(song.tracks[0].staves[0].stringTuning.name).toBe('Guitar Standard Tuning');
});

test('a retune is undoable and survives the .gp round-trip', async () => {
  const settings = new alphaTab.Settings();
  const song = score(dStandardRiff);
  const original = History.snapshot(song);
  const history = new History(10, settings);
  const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 1 };
  const result = runCommand(song, at, { op: 'retune', track: 0, tuning: E, octave: 0 }, history, settings);
  expect(result.edited).toBe(true);
  expect(result.marks).toHaveLength(2);

  const copy = alphaTab.importer.ScoreLoader.loadScoreFromBytes(new alphaTab.exporter.Gp7Exporter().export(song, settings), settings);
  expect(copy.tracks[0].staves[0].tuning).toEqual(E);
  expect(placed(copy, 0)).toEqual(placed(song, 0));

  const restored = await history.undo(song);
  expect(History.snapshot(restored!)).toBe(original);
});

test('retuning to the same tuning changes nothing', () => {
  const song = score(dStandardRiff);
  const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 1 };
  expect(runCommand(song, at, { op: 'retune', track: 0, tuning: D, octave: 0 }, new History()).edited).toBe(false);
});

test('retune refuses other tracks, tunings and octaves', () => {
  const song = score(dStandardRiff);
  expect(() => retune(song, 0, [], 0)).toThrow('a tuning needs 1 to 10 strings');
  expect(() => retune(song, 0, E, 3)).toThrow('octave must be -2 to 2');
});

test.skipIf(!process.env.DUOSCORE_PRIVATE_SAMPLE)('the private sample keeps every note through a retune', () => {
  for (const tuning of [D, E]) {
    const song = alphaTab.importer.ScoreLoader.loadScoreFromBytes(
      new Uint8Array(readFileSync(process.env.DUOSCORE_PRIVATE_SAMPLE!)),
      new alphaTab.Settings(),
    );
    const before = notes(song).map((n) => n.realValue);
    const marks = retune(song, 0, tuning, 0);
    const after = notes(song);
    expect(after).toHaveLength(before.length);
    const unplayable = new Set(marks.filter((m) => m.kind === 'unplayable').map((m) => `${m.bar}/${m.voice}/${m.beat}/${m.string}`));
    for (const [i, note] of after.entries()) {
      const key = `${note.beat.voice.bar.index}/${note.beat.voice.index}/${note.beat.index}/${note.string}`;
      if (!unplayable.has(key)) expect(note.realValue).toBe(before[i]);
    }
  }
}, 60_000);
