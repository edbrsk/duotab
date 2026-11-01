import type * as alphaTab from '@coderline/alphatab';

import type { ChordPosition, ChordSpec } from '../protocol';
import { chordTones } from './chord_names';

const SPAN = 3;
const FINGERS = 4;

/** Low string first, as sounding: frets count from the capo. */
export function openStringsOf(staff: alphaTab.model.Staff): number[] {
  return [...staff.tuning].reverse().map((pitch) => pitch + staff.capo);
}

/**
 * Fingers a shape needs: one per fretted note, except that the first finger
 * may barre one unbroken run of strings at the lowest fret.
 */
export function fingersFor(frets: number[]): number {
  const fretted = frets.filter((f) => f > 0);
  if (fretted.length === 0) return 0;
  const lowest = Math.min(...fretted);
  let best = 0;
  let run = 0;
  for (const f of frets) {
    if (f <= 0) {
      run = 0;
      continue;
    }
    if (f === lowest) run++;
    best = Math.max(best, run);
  }
  return best >= 2 ? fretted.length - best + 1 : fretted.length;
}

/** The best playable shapes of `spec` at each place on the neck, open position first. `openStrings` are MIDI pitches, low string first. */
export function chordPositions(spec: ChordSpec, openStrings: number[], maxFret = 24): ChordPosition[] {
  const { required, optional } = chordTones(spec);
  const bass = spec.bass ?? spec.root;
  const allowed = new Set([...required, ...optional, bass]);
  const options = openStrings.map((open) => {
    const list = [-1];
    for (let f = 0; f <= maxFret; f++) if (allowed.has((open + f) % 12)) list.push(f);
    return list;
  });
  const found: ChordPosition[] = [];
  const frets = new Array<number>(openStrings.length).fill(-1);

  // A power chord can be two notes; a chord, four strings when the guitar has them.
  const fewest = spec.type === '5' ? 2 : Math.min(openStrings.length, Math.max(4, required.length));
  const keep = () => {
    const sounding = frets.flatMap((f, i) => (f >= 0 ? [(openStrings[i] + f) % 12] : []));
    if (sounding.length < fewest || !required.every((p) => sounding.includes(p))) return;
    if (gaps(frets) > 1) return;
    if (fingersFor(frets) > FINGERS) return;
    const fretted = frets.filter((f) => f > 0);
    const lowestFret = fretted.length ? Math.min(...fretted) : 0;
    const open = frets.includes(0) && (fretted.length === 0 || Math.max(...fretted) <= 4);
    // Open strings ringing under a shape up the neck are rarely what a player wants.
    if (frets.includes(0) && !open) return;
    found.push({ frets: [...frets], open, lowestFret });
  };

  const search = (string: number, low: number, high: number, sounding: boolean) => {
    if (string === openStrings.length) return keep();
    for (const f of options[string]) {
      if (f > 0 && Math.max(high, f) - Math.min(low, f) > SPAN) continue;
      // The lowest sounding note is the bass.
      if (f >= 0 && !sounding && (openStrings[string] + f) % 12 !== bass) continue;
      frets[string] = f;
      search(string + 1, f > 0 ? Math.min(low, f) : low, f > 0 ? Math.max(high, f) : high, sounding || f >= 0);
    }
    frets[string] = -1;
  };
  search(0, Infinity, -Infinity, false);

  return bestByRegion(withoutSubsets(found));
}

/** Unplayed strings between the lowest and highest played ones. */
function gaps(frets: number[]): number {
  const first = frets.findIndex((f) => f >= 0);
  const last = frets.length - 1 - [...frets].reverse().findIndex((f) => f >= 0);
  return frets.slice(first, last + 1).filter((f) => f < 0).length;
}

const span = (frets: number[]) => {
  const fretted = frets.filter((f) => f > 0);
  return fretted.length ? Math.max(...fretted) - Math.min(...fretted) : 0;
};

/**
 * Drops a shape that another plays on more strings with the same frets, no
 * more fingers, gaps or stretch: the fuller one is as easy.
 */
function withoutSubsets(positions: ChordPosition[]): ChordPosition[] {
  const fingers = positions.map((p) => fingersFor(p.frets));
  const spans = positions.map((p) => span(p.frets));
  const strings = positions.map((p) => p.frets.filter((f) => f >= 0).length);
  const gapCounts = positions.map((p) => gaps(p.frets));
  return positions.filter((p, i) =>
    !positions.some(
      (q, j) =>
        strings[j] > strings[i] &&
        fingers[j] <= fingers[i] &&
        spans[j] <= spans[i] &&
        gapCounts[j] <= gapCounts[i] &&
        p.frets.every((f, s) => f < 0 || q.frets[s] === f),
    ),
  );
}

const PER_REGION = 4;

/** The few easiest shapes at each place on the neck, lowest first; open position is one place. */
function bestByRegion(positions: ChordPosition[]): ChordPosition[] {
  const strings = (p: ChordPosition) => p.frets.filter((f) => f >= 0).length;
  // Every finger in use is a stretch; three or fewer leave the hand free.
  const allFingers = (p: ChordPosition) => Number(fingersFor(p.frets) >= FINGERS);
  const better = (a: ChordPosition, b: ChordPosition) =>
    gaps(a.frets) - gaps(b.frets) ||
    allFingers(a) - allFingers(b) ||
    strings(b) - strings(a) ||
    fingersFor(a.frets) - fingersFor(b.frets) ||
    span(a.frets) - span(b.frets) ||
    a.frets.join().localeCompare(b.frets.join());
  const shapes = new Set(positions.map((p) => p.frets.join()));
  // A shape twelve frets up is the same shape an octave higher.
  const octaveCopy = (p: ChordPosition) =>
    !p.open && p.lowestFret >= 12 && shapes.has(p.frets.map((f) => (f < 0 ? f : f - 12)).join());
  const regions = new Map<number, ChordPosition[]>();
  for (const p of positions) {
    if (octaveCopy(p)) continue;
    const region = p.open ? 0 : p.lowestFret;
    regions.set(region, [...(regions.get(region) ?? []), p]);
  }
  return [...regions.keys()]
    .sort((a, b) => a - b)
    .flatMap((region) => regions.get(region)!.sort(better).slice(0, PER_REGION));
}
