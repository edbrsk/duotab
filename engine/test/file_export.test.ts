import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { fileGp, filePdf } from '../src/file_export';
import { gpBytes, longRiff, pitchOnlyXml, twoGuitarsAndDrums } from './fixtures';

const fontUrl = 'http://127.0.0.1:1/alphatab/font/Bravura.woff2';
const xml = new TextEncoder().encode(pitchOnlyXml);

test('a file converts to .gp with its fingering', () => {
  const song = alphaTab.importer.ScoreLoader.loadScoreFromBytes(fileGp(xml), new alphaTab.Settings());
  expect(song.tracks[0].staves[0].tuning).toEqual([64, 59, 55, 50, 45, 40]);
  expect(song.tracks[0].staves[0].bars[0].voices[0].beats[0].notes.every((n) => n.string >= 1)).toBe(true);
});

test('a file prints its first guitar track', () => {
  const pages = filePdf(gpBytes(longRiff), [], alphaTab.StaveProfile.ScoreTab, fontUrl);
  expect(pages.length).toBeGreaterThanOrEqual(2);
  expect(pages[0]).toContain('>Riff</text>');
});

test('a file prints with the staves chosen for that track', () => {
  const both = filePdf(gpBytes(longRiff), [], alphaTab.StaveProfile.ScoreTab, fontUrl);
  const notationOnly = filePdf(gpBytes(longRiff), [{ index: 0, notation: true, tab: false }], alphaTab.StaveProfile.ScoreTab, fontUrl);
  expect(notationOnly.join('').length).toBeLessThan(both.join('').length);
});

test('a file without a guitar track has no PDF', () => {
  const drums = gpBytes(twoGuitarsAndDrums.split('\\track "Guitar 1"')[0] + String.raw`\track "Drums" \instrument percussion
\articulation defaults
42.4`);
  expect(() => filePdf(drums, [], alphaTab.StaveProfile.ScoreTab, fontUrl)).toThrow('no guitar track');
});
