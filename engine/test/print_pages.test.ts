import { readFileSync } from 'node:fs';

import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { paginate, printPages, renderParts } from '../src/print_pages';
import { showNotationAndTab } from '../src/staves';
import { longRiff, score } from './fixtures';

const fontUrl = 'http://127.0.0.1:1234/alphatab/font/Bravura.woff2';
const profile = alphaTab.StaveProfile.ScoreTab;
const svgCount = (pages: string[]) => pages.join('').split('<svg').length - 1;

test('paginate fills pages and never splits a part', () => {
  const parts = [
    { y: 0, height: 100 },
    { y: 100, height: 300 },
    { y: 400, height: 300 },
    { y: 700, height: 300 },
  ];
  expect(paginate(parts, 770)).toEqual([[0, 1, 2], [3]]);
});

test('a part taller than a page gets a page of its own', () => {
  const parts = [
    { y: 0, height: 100 },
    { y: 100, height: 900 },
    { y: 1000, height: 100 },
  ];
  expect(paginate(parts, 770)).toEqual([[0], [1], [2]]);
});

test('printPages lays the song on numbered A4 pages', () => {
  const pages = printPages(score(longRiff), 0, profile, fontUrl);
  expect(pages.length).toBeGreaterThanOrEqual(2);
  expect(pages[0]).toContain('>Riff</text>');
  expect(pages[0]).toContain('= 140');
  for (const [i, page] of pages.entries()) {
    expect(page).toContain('<meta name="viewport" content="width=595, initial-scale=1">');
    expect(page).toContain(fontUrl);
    expect(page).toContain(`${i + 1} / ${pages.length}`);
  }
  expect(pages.at(-1)).toContain('rendered by alphaTab');
});

test('every system is printed once', () => {
  const song = score(longRiff);
  expect(svgCount(printPages(song, 0, profile, fontUrl))).toBe(renderParts(song, 0, profile).length);
});

test('titles are escaped', () => {
  const pages = printPages(score(longRiff.replace('"Riff"', '"Rock & <Roll>"')), 0, profile, fontUrl);
  expect(pages[0]).toContain('Rock &amp; &lt;Roll&gt;');
  expect(pages.join('')).not.toContain('<Roll>');
});

test.skipIf(!process.env.DUOSCORE_PRIVATE_SAMPLE)('the private sample prints every system', () => {
  const bytes = new Uint8Array(readFileSync(process.env.DUOSCORE_PRIVATE_SAMPLE!));
  const song = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, new alphaTab.Settings());
  // As the app lays it out: notation over tab, whatever the file saved.
  showNotationAndTab(song);
  const started = performance.now();
  const pages = printPages(song, 0, profile, fontUrl);
  expect(performance.now() - started).toBeLessThan(20_000);
  expect(pages.length).toBeGreaterThanOrEqual(5);
  expect(svgCount(pages)).toBe(renderParts(song, 0, profile).length);
}, 60_000);
