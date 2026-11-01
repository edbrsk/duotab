import { expect, test } from 'vitest';

import { carryPlaybackSettings, firstPassStarts, rangeAfterRestore, rangeAfterTap } from '../../src/editing/restore';
import { score, twoGuitarsAndDrums } from '../fixtures';

test('a restored song keeps the tones and staves chosen since', () => {
  const current = score(twoGuitarsAndDrums);
  const restored = score(twoGuitarsAndDrums);
  current.tracks[0].playbackInfo.program = 30;
  current.tracks[1].staves[0].showStandardNotation = false;
  current.tracks[1].staves[0].showSlash = true;
  current.tracks[1].staves[0].showNumbered = true;

  carryPlaybackSettings(current, restored);

  expect(restored.tracks[1].staves[0].showSlash).toBe(true);
  expect(restored.tracks[1].staves[0].showNumbered).toBe(true);

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

test('a restored song keeps each track its tone, volume and staves, matched by channel', () => {
  const current = score(twoGuitarsAndDrums);
  const restored = score(twoGuitarsAndDrums);
  // The current song has the first two tracks the other way round.
  const [a, b] = current.tracks.splice(0, 2);
  current.tracks.unshift(b, a);
  a.playbackInfo.program = 30;
  a.playbackInfo.volume = 5;
  b.staves[0].showTablature = false;

  carryPlaybackSettings(current, restored);

  expect([restored.tracks[0].playbackInfo.program, restored.tracks[0].playbackInfo.volume]).toEqual([30, 5]);
  expect(restored.tracks[1].staves[0].showTablature).toBe(false);
  expect(restored.tracks[0].staves[0].showTablature).toBe(true);
});

test('an undo that moves the bars clears the loop', () => {
  const range = { startTick: 3840, endTick: 7680 };
  expect(rangeAfterRestore([0, 3840, 7680], [0, 3840, 7680], range)).toBe(range);
  expect(rangeAfterRestore([0, 3840, 7680], [0, 2880, 6720], range)).toBeNull();
  expect(rangeAfterRestore([0, 3840], [0, 3840, 7680], null)).toBeNull();
});

test('an undo of a repeat clears the loop', () => {
  const plain = score(String.raw`\track "G" \tuning E4 B3 G3 D3 A2 E2
r.1 | r.1 | r.1`);
  const repeated = score(String.raw`\track "G" \tuning E4 B3 G3 D3 A2 E2
\ro r.1 | \rc 2 r.1 | r.1`);
  // The written positions match; only playback, which loops count in, differs.
  expect(plain.masterBars.map((m) => m.start)).toEqual(repeated.masterBars.map((m) => m.start));
  const range = { startTick: 7680, endTick: 11520 };
  expect(rangeAfterRestore(firstPassStarts(repeated), firstPassStarts(plain), range)).toBeNull();
});

test("undo keeps the tone over the file's instrument changes", () => {
  const tex = String.raw`\track "G" \instrument 29 \tuning E4 B3 G3 D3 A2 E2
0.6.4{instrument 29} 0.6.4 0.6.2 | 0.6.1{instrument 30}`;
  const current = score(tex);
  current.tracks[0].playbackInfo.program = 27;
  const restored = score(tex);
  carryPlaybackSettings(current, restored);
  const values = restored.tracks[0].staves[0].bars.flatMap((b) => b.voices[0].beats.flatMap((beat) => beat.automations.map((a) => a.value)));
  expect(values).toEqual([27, 27]);
});
