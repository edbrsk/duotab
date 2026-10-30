import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { drawnUnplayable, fingerUnstrung, positionCost } from '../../src/editing/fingering';
import { pitchesOnly, score, twoGuitarsAndDrums } from '../fixtures';

const placed = (song: alphaTab.model.Score, bar: number) =>
  song.tracks[0].staves[0].bars[bar].voices[0].beats.map((b) => b.notes.map((n) => `${n.string}/${n.fret}`));

const realValues = (song: alphaTab.model.Score) =>
  song.tracks[0].staves[0].bars.flatMap((bar) => bar.voices[0].beats.flatMap((b) => b.notes.map((n) => n.realValue)));

test('positionCost prefers open strings, low frets and a short stretch', () => {
  expect(positionCost([0], 0)).toBe(0);
  expect(positionCost([5], 0)).toBeCloseTo(5.5);
  expect(positionCost([1, 7], 0)).toBeCloseTo(8.8 + 20);
});

test('a pitch-only guitar part gets standard E strings and frets', () => {
  const song = score(pitchesOnly);
  const before = realValues(song);
  fingerUnstrung(song);
  expect(song.tracks[0].staves[0].tuning).toEqual([64, 59, 55, 50, 45, 40]);
  expect(song.tracks[0].staves[0].bars.every((bar) => bar.voices[0].beats.every((b) => b.notes.every((n) => n.string >= 1)))).toBe(true);
  const after = realValues(song);
  // C2 sits below the lowest string, so it alone changes pitch.
  expect(after.filter((v, i) => v !== before[i])).toEqual([40]);
});

test('the lowest position wins', () => {
  const song = score(pitchesOnly);
  fingerUnstrung(song);
  expect(placed(song, 0)).toEqual([['4/0'], ['4/2'], ['5/0'], ['5/1']]);
});

test('consecutive notes stay close', () => {
  const song = score(pitchesOnly);
  fingerUnstrung(song);
  expect(placed(song, 1)[2]).toEqual(['6/8']);
  expect(placed(song, 1)[3]).toEqual(['4/7']);
});

test('chord notes get distinct strings', () => {
  const song = score(pitchesOnly);
  fingerUnstrung(song);
  expect(placed(song, 1)[1].sort()).toEqual(['1/0', '5/0', '6/0']);
});

test('tied notes share string and fret', () => {
  const song = score(pitchesOnly);
  fingerUnstrung(song);
  expect(placed(song, 2)[2]).toEqual(['5/6']);
  expect(placed(song, 3)[0]).toEqual(['5/6']);
  expect(song.tracks[0].staves[0].bars[3].voices[0].beats[0].notes[0].tieOrigin).not.toBeNull();
});

test('notes no string can play are counted', () => {
  const song = score(pitchesOnly);
  const marks = fingerUnstrung(song);
  expect(placed(song, 2).slice(0, 2)).toEqual([['1/0'], ['6/32']]);
  expect(marks.get(0)).toEqual([
    { bar: 2, voice: 0, beat: 0, string: 1, kind: 'unplayable' },
    { bar: 2, voice: 0, beat: 1, string: 6, kind: 'unplayable' },
  ]);
});

test('stringed tracks and other instruments are left alone', () => {
  const song = score(twoGuitarsAndDrums);
  const before = alphaTab.model.JsonConverter.scoreToJson(song);
  expect(fingerUnstrung(song).size).toBe(0);
  expect(alphaTab.model.JsonConverter.scoreToJson(song)).toBe(before);

  const piano = score(pitchesOnly.replace('\\instrument 25', '\\instrument 0'));
  fingerUnstrung(piano);
  expect(piano.tracks[0].staves[0].tuning).toEqual([]);
});

test('a tie destination keeps its string apart from the chord around it', () => {
  for (const tex of ['E4.2 (E4{t} B4).2', 'E4.1 | (E4{t} C5).1']) {
    const song = score(String.raw`\track "P" \instrument 25 \tuning piano
${tex}`);
    fingerUnstrung(song);
    const chord = song.tracks[0].staves[0].bars.flatMap((b) => b.voices[0].beats).at(-1)!;
    expect(new Set(chord.notes.map((n) => n.string)).size).toBe(2);
    expect(chord.notes.find((n) => n.isTieDestination)!.tieOrigin).not.toBeNull();
  }
});

test('the fingering message counts only the drawn track', () => {
  const marks = new Map([[1, [{ bar: 0, voice: 0, beat: 0, string: 1, kind: 'unplayable' as const }]]]);
  expect(drawnUnplayable(score(twoGuitarsAndDrums), marks)).toBe(0);
  expect(drawnUnplayable(score(twoGuitarsAndDrums), new Map([[0, marks.get(1)!]]))).toBe(1);
});
