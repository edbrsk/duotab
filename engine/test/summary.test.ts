import { readFileSync } from 'node:fs';

import { expect, test } from 'vitest';

import { summarize, summarizeScore } from '../src/summary';
import { gpBytes, score, twoGuitarsAndDrums } from './fixtures';

test('summarizes a generated song with two guitars and drums', () => {
  const s = summarize(gpBytes(twoGuitarsAndDrums), 'Fixture.gp');
  expect(s.title).toBe('Fixture');
  expect(s.tracks.map((t) => t.kind)).toEqual(['guitar', 'guitar', 'drums']);
  expect(s.tracks[1].stringCount).toBe(7);
  expect(s.tracks[1].tuning).toEqual([64, 59, 55, 50, 45, 40, 35]);
  expect(s.tracks[0].midiProgram).toBe(29);
  expect(s.tracks[2].tuning).toBeNull();
});

test('falls back to the file name for an untitled song', () => {
  const s = summarize(gpBytes(twoGuitarsAndDrums.replace('\\title "Fixture"', '')), 'My Riff.gp');
  expect(s.title).toBe('My Riff');
});

test('summarize reports a broken file as an error', () => {
  expect(() => summarize(new TextEncoder().encode('not a song'), 'notes.gp5')).toThrow();
  expect(() => summarize(gpBytes(twoGuitarsAndDrums).slice(0, 200), 'truncated.gp')).toThrow();
});

test.skipIf(!process.env.DUOSCORE_PRIVATE_SAMPLE)('summarizes the private sample', () => {
  const s = summarize(new Uint8Array(readFileSync(process.env.DUOSCORE_PRIVATE_SAMPLE!)), '07 Collateral Damage.gp');
  expect(s.tracks).toHaveLength(7);
  expect(s.tracks.every((t) => t.kind === 'guitar' && t.stringCount === 6)).toBe(true);
  expect(s.tracks[0].tuning).toEqual([63, 58, 54, 49, 44, 39]);
});

test("summaries tell each track's volume and channel", () => {
  const s = score(twoGuitarsAndDrums);
  s.tracks[1].playbackInfo.volume = 9;
  const summary = summarizeScore(s, 'x.gp');
  expect(summary.tracks.map((t) => [t.volume, t.channel])).toEqual(
    s.tracks.map((t) => [t.playbackInfo.volume, t.playbackInfo.primaryChannel]),
  );
  expect(summary.tracks[1].volume).toBe(9);
});
