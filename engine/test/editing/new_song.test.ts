import { expect, test } from 'vitest';

import { newSong } from '../../src/editing/new_song';

const sevenStrings = [64, 59, 55, 50, 45, 40, 35];

test('creates the tuning, tempo and time signature asked for', () => {
  const s = newSong({ title: 'Riff', tuning: sevenStrings, tempo: 140, numerator: 6, denominator: 8 });
  expect(s.tracks).toHaveLength(1);
  expect(s.tracks[0].staves[0].tuning).toEqual(sevenStrings);
  expect(s.tempo).toBe(140);
  expect([s.masterBars[0].timeSignatureNumerator, s.masterBars[0].timeSignatureDenominator]).toEqual([6, 8]);
  expect(s.masterBars).toHaveLength(4);
  for (const bar of s.tracks[0].staves[0].bars) {
    const beats = bar.voices[0].beats;
    expect(beats.every((b) => b.isRest)).toBe(true);
    expect(beats.reduce((t, b) => t + b.playbackDuration, 0)).toBe(bar.masterBar.calculateDuration());
  }
});

test('the title becomes the song title, and the track is a clean guitar', () => {
  const s = newSong({ title: 'Riff "One"', tuning: sevenStrings.slice(0, 6), tempo: 120, numerator: 4, denominator: 4 });
  expect(s.title).toBe('Riff "One"');
  expect(s.tracks[0].name).toBe('Guitar');
  expect(s.tracks[0].playbackInfo.program).toBe(27);
});
