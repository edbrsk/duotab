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
 * may barre one unbroken run of strings at the lowest fret, and another
 * finger may barre the adjacent strings at the highest fret that end on the
 * top fretted string, as in an A-shape barre.
 */
export function fingersFor(frets: number[]): number {
  const { low, high } = barres(frets);
  return frets.filter((f) => f > 0).length - low - high;
}

/** Fingers each barre saves. */
function barres(frets: number[]): { low: number; high: number } {
  const fretted = frets.filter((f) => f > 0);
  if (fretted.length === 0) return { low: 0, high: 0 };
  const lowest = Math.min(...fretted);
  const highest = Math.max(...fretted);
  let low = 0;
  let high = 0;
  let lowRun = 0;
  let highRun = 0;
  for (const f of frets) {
    // The first finger lies under higher notes; another can't lie over lower ones.
    lowRun = f <= 0 ? 0 : lowRun + Number(f === lowest);
    low = Math.max(low, lowRun);
    if (f <= 0) continue;
    highRun = f === highest && highest > lowest ? highRun + 1 : 0;
    high = highRun;
  }
  const saved = (run: number) => (run >= 2 ? run - 1 : 0);
  return { low: saved(low), high: saved(high) };
}

/** The best playable shapes of `spec` at each place on the neck, open position first. `openStrings` are MIDI pitches, low string first. */
export function chordPositions(spec: ChordSpec, openStrings: number[], maxFret = 24): ChordPosition[] {
  return bestByRegion(candidatePositions(spec, openStrings, maxFret));
}

/** Every shape that plays `spec` within the hand's reach, before choosing the best. */
export function candidatePositions(spec: ChordSpec, openStrings: number[], maxFret = 24): ChordPosition[] {
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
  return found;
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

/** `q` plays `p` on more strings with the same frets, no more fingers, gaps or stretch: as easy, and fuller. */
function covers(q: number[], p: number[]): boolean {
  const strings = (frets: number[]) => frets.filter((f) => f >= 0).length;
  return (
    strings(q) > strings(p) &&
    fingersFor(q) <= fingersFor(p) &&
    span(q) <= span(p) &&
    gaps(q) <= gaps(p) &&
    p.every((f, s) => f < 0 || q[s] === f)
  );
}

const PER_REGION = 4;

/**
 * The few easiest shapes at each place on the neck, lowest first; open
 * position is one place. Places are decided from the nut up, so a shape is
 * left out for a fuller or lower copy only when that copy is kept.
 */
function bestByRegion(positions: ChordPosition[]): ChordPosition[] {
  const strings = (p: ChordPosition) => p.frets.filter((f) => f >= 0).length;
  // Every finger in use is a stretch; three or fewer leave the hand free.
  const allFingers = (p: ChordPosition) => Number(fingersFor(p.frets) >= FINGERS);
  const better = (a: ChordPosition, b: ChordPosition) =>
    gaps(a.frets) - gaps(b.frets) ||
    allFingers(a) - allFingers(b) ||
    strings(b) - strings(a) ||
    fingersFor(a.frets) - fingersFor(b.frets) ||
    // A barre at the top of a shape is harder to hold than separate fingers.
    Number(barres(a.frets).high > 0) - Number(barres(b.frets).high > 0) ||
    span(a.frets) - span(b.frets) ||
    a.frets.join().localeCompare(b.frets.join());
  const regions = new Map<number, ChordPosition[]>();
  for (const p of positions) {
    const region = p.open ? 0 : p.lowestFret;
    regions.set(region, [...(regions.get(region) ?? []), p]);
  }
  const kept: ChordPosition[] = [];
  const shown = (frets: number[]) => kept.some((q) => q.frets.join() === frets.join() || covers(q.frets, frets));
  for (const region of [...regions.keys()].sort((a, b) => a - b)) {
    const here = regions.get(region)!.filter((p) => {
      if (shown(p.frets)) return false;
      // A shape twelve frets up is the same shape an octave higher.
      return p.open || p.lowestFret < 12 || !shown(p.frets.map((f) => (f < 0 ? f : f - 12)));
    });
    // A fuller shape here ranks above the one it covers, so it's kept whenever that one would be.
    const best = here.filter((p) => !here.some((q) => covers(q.frets, p.frets)));
    kept.push(...best.sort(better).slice(0, PER_REGION));
  }
  return kept;
}
