import { expect, test } from 'vitest';

import {
  dbFromVolume,
  masterDbFromStored,
  panFromStored,
  storedFromPan,
  storedFromTrackDb,
  trackDbFromStored,
} from '../src/mix_values';

test("Guitar Pro's track volume is linear in dB", () => {
  expect(trackDbFromStored(0.92)).toBeCloseTo(6, 6);
  expect(trackDbFromStored(0.795)).toBeCloseTo(-0.25, 6);
  expect(trackDbFromStored(0.68)).toBeCloseTo(-6, 6);
  expect(trackDbFromStored(0.4)).toBeCloseTo(-20, 6);
});

test('a track dB is stored back as Guitar Pro reads it', () => {
  expect(storedFromTrackDb(0)).toBeCloseTo(0.8, 6);
  expect(storedFromTrackDb(-6)).toBeCloseTo(0.68, 6);
  expect(storedFromTrackDb(null)).toBe(0);
  expect(storedFromTrackDb(20)).toBe(1);
});

test("Guitar Pro's master volume", () => {
  expect(masterDbFromStored(0.76)).toBeCloseTo(0, 6);
  expect(masterDbFromStored(0.61)).toBeCloseTo(-6, 6);
});

test('pan runs from full left to full right', () => {
  expect(panFromStored(0)).toBe(-1);
  expect(panFromStored(0.5)).toBe(0);
  expect(panFromStored(1)).toBe(1);
  expect(storedFromPan(-1)).toBe(0);
});

test('a 0–16 volume plays as its cube against 12', () => {
  expect(dbFromVolume(12)).toBeCloseTo(0, 6);
  expect(dbFromVolume(6)).toBeCloseTo(-18.06, 2);
  expect(dbFromVolume(0)).toBeNull();
});
