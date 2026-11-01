import { expect, test } from 'vitest';

import { setStaves, showNotationAndTab } from '../src/staves';
import { score, twoGuitarsAndDrums } from './fixtures';

test('opens every string track with notation and tab', () => {
  const s = score(twoGuitarsAndDrums);
  s.tracks[0].staves[0].showStandardNotation = false;
  s.tracks[1].staves[0].showTablature = false;
  const drums = s.tracks[2].staves[0];
  const drumsBefore = [drums.showStandardNotation, drums.showTablature];

  showNotationAndTab(s);

  for (const t of [0, 1]) {
    expect(s.tracks[t].staves[0].showStandardNotation).toBe(true);
    expect(s.tracks[t].staves[0].showTablature).toBe(true);
  }
  expect([drums.showStandardNotation, drums.showTablature]).toEqual(drumsBefore);
});

test('setStaves hides what is asked', () => {
  const s = score(twoGuitarsAndDrums);
  setStaves(s, [{ index: 0, notation: false, tab: true, slash: false, numbered: false }]);
  expect(s.tracks[0].staves[0].showStandardNotation).toBe(false);
  expect(s.tracks[0].staves[0].showTablature).toBe(true);
});

test('setStaves refuses to hide both', () => {
  expect(() => setStaves(score(twoGuitarsAndDrums), [{ index: 0, notation: false, tab: false, slash: false, numbered: false }])).toThrow(
    'a track needs notation or tab',
  );
});

test('setStaves draws slash and numbered alongside tab', () => {
  const s = score(twoGuitarsAndDrums);
  setStaves(s, [{ index: 0, notation: false, tab: true, slash: true, numbered: true }]);
  const staff = s.tracks[0].staves[0];
  expect([staff.showStandardNotation, staff.showTablature, staff.showSlash, staff.showNumbered]).toEqual([false, true, true, true]);
});

test('slash or numbered alone is refused', () => {
  expect(() =>
    setStaves(score(twoGuitarsAndDrums), [{ index: 0, notation: false, tab: false, slash: true, numbered: true }]),
  ).toThrow('a track needs notation or tab');
});

test('opening shows notation and tab only', () => {
  const s = score(twoGuitarsAndDrums);
  const staff = s.tracks[0].staves[0];
  staff.showSlash = true;
  staff.showNumbered = true;
  showNotationAndTab(s);
  expect([staff.showStandardNotation, staff.showTablature, staff.showSlash, staff.showNumbered]).toEqual([true, true, false, false]);
});
