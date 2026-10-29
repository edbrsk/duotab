import { expect, test } from 'vitest';

import { barAtTick, barsWithNotes, barTimeline } from '../src/timeline';
import { repeated, score, tempoAndSections } from './fixtures';

test('barTimeline gives start, tempo and section per bar', () => {
  expect(barTimeline(score(tempoAndSections))).toEqual([
    { index: 0, startTick: 0, startMs: 0, tempo: 120, section: { marker: 'A', text: 'Intro' } },
    { index: 1, startTick: 3840, startMs: 2000, tempo: 60, section: null },
    { index: 2, startTick: 7680, startMs: 6000, tempo: 60, section: { marker: 'B', text: 'Verse' } },
    { index: 3, startTick: 11520, startMs: 10000, tempo: 60, section: null },
  ]);
});

test('barTimeline uses the first pass through a repeat', () => {
  expect(barTimeline(score(repeated)).map((b) => [b.startTick, b.startMs])).toEqual([
    [0, 0],
    [3840, 2000],
    [15360, 8000],
  ]);
});

test('barsWithNotes is false for rest-only bars', () => {
  expect(barsWithNotes(score(tempoAndSections).tracks[0])).toEqual([true, true, false, true]);
});

test('barAtTick finds the bar being played, repeats included', () => {
  const lookups = [0, 1, 0, 1, 2].map((index, i) => ({
    start: i * 3840,
    end: (i + 1) * 3840,
    masterBar: { index },
  }));
  expect(barAtTick(lookups, 0)).toBe(0);
  expect(barAtTick(lookups, 9000)).toBe(0);
  expect(barAtTick(lookups, 12000)).toBe(1);
  expect(barAtTick(lookups, 99999)).toBe(2);
});
