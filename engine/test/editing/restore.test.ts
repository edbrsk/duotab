import { expect, test } from 'vitest';

import { carryPlaybackSettings, rangeAfterTap } from '../../src/editing/restore';
import { score, twoGuitarsAndDrums } from '../fixtures';

test('a restored song keeps the tones and staves chosen since', () => {
  const current = score(twoGuitarsAndDrums);
  const restored = score(twoGuitarsAndDrums);
  current.tracks[0].playbackInfo.program = 30;
  current.tracks[1].staves[0].showStandardNotation = false;

  carryPlaybackSettings(current, restored);

  expect(restored.tracks[0].playbackInfo.program).toBe(30);
  expect(restored.tracks[1].staves[0].showStandardNotation).toBe(false);
  expect(restored.tracks[1].staves[0].showTablature).toBe(true);
});

test('a tap inside the loop keeps it, and elsewhere clears it', () => {
  const range = { startTick: 960, endTick: 3840 };
  expect(rangeAfterTap(range, 960)).toBe(range);
  expect(rangeAfterTap(range, 3000)).toBe(range);
  expect(rangeAfterTap(range, 0)).toBeNull();
  expect(rangeAfterTap(range, 3840)).toBeNull();
  expect(rangeAfterTap(null, 100)).toBeNull();
});
