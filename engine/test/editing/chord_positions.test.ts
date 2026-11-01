import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { chordTones } from '../../src/editing/chord_names';
import { candidatePositions, chordPositions, fingersFor, openStringsOf } from '../../src/editing/chord_positions';
import type { ChordAddition, ChordSpec, ChordType } from '../../src/protocol';

const E_STANDARD = [40, 45, 50, 55, 59, 64];
const DROP_B = [35, 42, 47, 52, 56, 61];
const B_SEVEN = [35, 40, 45, 50, 55, 59, 64];
const F_SHARP_EIGHT = [30, 35, 40, 45, 50, 55, 59, 64];

const chord = (root: number, type: ChordType, additions: ChordAddition[] = []): ChordSpec => ({
  root,
  type,
  additions,
  bass: null,
});
const cmaj7 = chord(0, 'maj7');
const frets = (positions: { frets: number[] }[]) => positions.map((p) => p.frets);

const types: ChordType[] = ['maj', 'm', '7', 'maj7', 'm7', 'm7b5', 'dim7', 'aug', 'sus2', 'sus4', '6', '5'];
const additions: (ChordAddition | null)[] = [null, 'b9', '9', '#9', '11', '#11', 'b13', '13'];

test('Cmaj7 in E standard', () => {
  const positions = chordPositions(cmaj7, E_STANDARD);
  expect(frets(positions)).toEqual(expect.arrayContaining([[-1, 3, 2, 0, 0, 0], [-1, 3, 5, 4, 5, 3], [8, -1, 9, 9, 8, 8]]));
  expect(positions[0]).toEqual({ frets: [-1, 3, 2, 0, 0, 0], open: true, lowestFret: 2 });
  // Open position first, then up the neck.
  const region = (p: { open: boolean; lowestFret: number }) => (p.open ? 0 : p.lowestFret);
  for (let i = 1; i < positions.length; i++) expect(region(positions[i - 1])).toBeLessThanOrEqual(region(positions[i]));
});

test('a few shapes at each place on the neck, none twelve frets above another', () => {
  const positions = chordPositions(cmaj7, E_STANDARD);
  const regions = new Map<number, number>();
  for (const p of positions) regions.set(p.open ? 0 : p.lowestFret, (regions.get(p.open ? 0 : p.lowestFret) ?? 0) + 1);
  expect(Math.max(...regions.values())).toBeLessThanOrEqual(4);
  const shapes = new Set(frets(positions).map((f) => f.join()));
  for (const f of frets(positions)) expect(shapes.has(f.map((x) => (x < 0 ? x : x - 12)).join()), `${f}`).toBe(false);
});

test('open strings only in open position', () => {
  for (const { frets: f, open } of chordPositions(cmaj7, E_STANDARD)) if (f.includes(0)) expect(open, `${f}`).toBe(true);
});

test('B7♭9 in E standard', () => {
  expect(frets(chordPositions(chord(11, '7', ['b9']), E_STANDARD))).toEqual(
    expect.arrayContaining([[-1, 2, 1, 2, 1, 2], [7, -1, 7, 8, 7, 8]]),
  );
});

test('Cmaj7 in drop B', () => {
  expect(frets(chordPositions(cmaj7, DROP_B))).toContainEqual([1, 1, 0, 0, 3, 3]);
});

test('no position needs five fingers', () => {
  expect(fingersFor([-1, 3, 2, 4, 5, 3])).toBe(5);
  expect(fingersFor([7, -1, 7, 8, 7, 8])).toBe(4);
  expect(fingersFor([-1, 3, 5, 4, 5, 3])).toBe(4);
  expect(frets(chordPositions(cmaj7, E_STANDARD))).not.toContainEqual([-1, 3, 2, 4, 5, 3]);
});

test('every position keeps the rules', () => {
  const broken: string[] = [];
  for (const tuning of [E_STANDARD, DROP_B, B_SEVEN]) {
    for (let root = 0; root < 12; root++) {
      for (const type of types) {
        for (const addition of additions) {
          const spec = chord(root, type, addition ? [addition] : []);
          const { required, optional } = chordTones(spec);
          for (const { frets: f } of chordPositions(spec, tuning)) {
            const fretted = f.filter((x) => x > 0);
            const sounding = f.flatMap((x, i) => (x >= 0 ? [(tuning[i] + x) % 12] : []));
            const ok =
              (fretted.length === 0 || Math.max(...fretted) - Math.min(...fretted) <= 3) &&
              Math.max(...f) <= 24 &&
              fingersFor(f) <= 4 &&
              sounding.every((p) => required.includes(p) || optional.includes(p)) &&
              sounding[0] === root &&
              required.every((p) => sounding.includes(p));
            if (!ok) broken.push(`${tuning} ${root}${type}${addition ?? ''}: ${f}`);
          }
        }
      }
    }
  }
  expect(broken).toEqual([]);
}, 60_000);

test('a finger can also barre the highest fret', () => {
  expect(fingersFor([-1, 3, 2, 3, 3, 3])).toBe(3);
  expect(fingersFor([-1, 0, 2, 2, 2, 0])).toBe(1);
  // A barre higher up would sound over the lower note between.
  expect(fingersFor([-1, 3, 3, 2, 3, 3])).toBe(4);
  // Only up to the top fretted string, as players hold it.
  expect(fingersFor([1, 0, 2, 2, 1, 0])).toBe(4);
  expect(frets(chordPositions(chord(0, '7', ['9']), E_STANDARD))).toContainEqual([-1, 3, 2, 3, 3, 3]);
});

test('a chord no hand can hold has no positions', () => {
  expect(chordPositions(chord(0, 'dim7', ['b9', '#11', 'b13']), E_STANDARD)).toEqual([]);
});

test('a slash chord has its bass lowest', () => {
  const positions = chordPositions({ root: 4, type: 'm', additions: [], bass: 0 }, E_STANDARD);
  expect(frets(positions)).toContainEqual([-1, 3, 2, 0, 0, 0]);
  for (const { frets: f } of positions) {
    const lowest = f.findIndex((x) => x >= 0);
    expect((E_STANDARD[lowest] + f[lowest]) % 12).toBe(0);
  }
});

test('a capo shifts the open strings', () => {
  const staff = new alphaTab.model.Staff();
  staff.stringTuning.tunings = [64, 59, 55, 50, 45, 40];
  staff.capo = 2;
  expect(openStringsOf(staff)).toEqual([42, 47, 52, 57, 61, 66]);
});

test('an 8-string track finds every chord quickly', () => {
  const started = performance.now();
  for (let root = 0; root < 12; root++) {
    for (const type of types) {
      for (const { frets: f } of chordPositions(chord(root, type), F_SHARP_EIGHT)) expect(f).toHaveLength(8);
    }
  }
  expect(performance.now() - started).toBeLessThan(3000);
});

test('fragments and needless subsets are left out', () => {
  const positions = frets(chordPositions(chord(0, 'maj'), E_STANDARD));
  expect(positions).toContainEqual([-1, 3, 2, 0, 1, 0]);
  expect(positions).not.toContainEqual([-1, -1, -1, -1, 1, 0]);
  expect(positions).not.toContainEqual([-1, 3, 2, 0, 1, -1]);
  expect(positions).not.toContainEqual([-1, 3, -1, -1, 1, 0]);
  expect(positions.length).toBeLessThanOrEqual(60);
});

test('the voicings guitarists know are offered', () => {
  const has = (spec: ChordSpec, shape: number[]) =>
    expect(frets(chordPositions(spec, E_STANDARD)), `${spec.root}${spec.type} ${shape}`).toContainEqual(shape);
  has(chord(5, 'maj7'), [-1, -1, 3, 2, 1, 0]);
  has(chord(9, '5'), [-1, 0, 2, 2, -1, -1]);
  has(chord(4, '5'), [0, 2, 2, -1, -1, -1]);
  has(chord(4, 'm7'), [0, 2, 2, 0, 3, 0]);
  has(chord(11, 'dim7'), [-1, 2, 3, 1, 3, 1]);
  has(chord(0, 'maj'), [-1, 3, 2, 0, 1, 0]);
  has(chord(9, 'm'), [-1, 0, 2, 2, 1, 0]);
  has(chord(7, '7'), [3, 2, 0, 0, 0, 1]);
  has(chord(2, 'maj'), [-1, -1, 0, 2, 3, 2]);
  has(chord(4, 'maj'), [0, 2, 2, 1, 0, 0]);
  has(chord(5, 'maj'), [1, 3, 3, 2, 1, 1]);
});

test('a shape needing every finger never leads its place on the neck', () => {
  for (const spec of [chord(5, 'maj7'), chord(5, 'maj'), chord(0, 'maj'), chord(4, 'maj'), chord(7, '7')]) {
    expect(fingersFor(chordPositions(spec, E_STANDARD)[0].frets), `${spec.root}${spec.type}`).toBeLessThanOrEqual(3);
  }
});

test('a shape left out is cut for room, or has a fuller or lower copy kept', () => {
  const region = (p: { open: boolean; lowestFret: number }) => (p.open ? 0 : p.lowestFret);
  const lost: string[] = [];
  for (const tuning of [E_STANDARD, DROP_B]) {
    for (let root = 0; root < 12; root++) {
      for (const type of types) {
        const spec = chord(root, type);
        const kept = chordPositions(spec, tuning);
        const keptShapes = new Set(kept.map((p) => p.frets.join()));
        const perRegion = (r: number) => kept.filter((p) => region(p) === r).length;
        for (const p of candidatePositions(spec, tuning)) {
          if (keptShapes.has(p.frets.join()) || perRegion(region(p)) === 4) continue;
          const coveredByKept = (frets: number[]) =>
            kept.some((q) => q.frets.join() !== frets.join() && frets.every((f, s) => f < 0 || q.frets[s] === f));
          const lower = p.frets.map((f) => (f < 0 ? f : f - 12));
          const lowerKept = !p.open && p.lowestFret >= 12 && (keptShapes.has(lower.join()) || coveredByKept(lower));
          if (!lowerKept && !coveredByKept(p.frets)) lost.push(`${tuning} ${root}${type}: ${p.frets}`);
        }
      }
    }
  }
  expect(lost).toEqual([]);
}, 60_000);
