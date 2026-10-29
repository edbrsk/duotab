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
  setStaves(s, [{ index: 0, notation: false, tab: true }]);
  expect(s.tracks[0].staves[0].showStandardNotation).toBe(false);
  expect(s.tracks[0].staves[0].showTablature).toBe(true);
});

test('setStaves refuses to hide both', () => {
  expect(() => setStaves(score(twoGuitarsAndDrums), [{ index: 0, notation: false, tab: false }])).toThrow(
    'a track needs notation or tab',
  );
});
