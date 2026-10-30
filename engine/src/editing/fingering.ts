import * as alphaTab from '@coderline/alphatab';

import { finishEdit } from './finish';
import { isGuitar } from './tracks';

type Score = alphaTab.model.Score;
type Bar = alphaTab.model.Bar;
type Beat = alphaTab.model.Beat;
type Note = alphaTab.model.Note;

export const MAX_FRET = 24;

const STANDARD_E = [64, 59, 55, 50, 45, 40];
const STRETCH = 4;
// Weighs a note left unplaced above any placement the search can find.
const UNPLACED = 1000;

export type NoteMark = { bar: number; voice: number; beat: number; string: number; kind: 'moved' | 'unplayable' };

/** Lower is easier to play: near the hand, low on the neck, within a four-fret stretch. */
export function positionCost(frets: number[], anchor: number): number {
  const fretted = frets.filter((f) => f > 0);
  const near = fretted.reduce((sum, f) => sum + Math.abs(f - anchor), 0);
  const low = 0.1 * frets.reduce((sum, f) => sum + f, 0);
  const span = fretted.length ? Math.max(...fretted) - Math.min(...fretted) : 0;
  return near + low + (span > STRETCH ? 10 * (span - STRETCH) : 0);
}

const startOf = (beat: Beat) => beat.playbackStart;
const endOf = (beat: Beat) => beat.playbackStart + Math.max(beat.playbackDuration, 1);

/** No other note in the bar, in any voice, sits on `string` while `beat` sounds. */
export function isFree(bar: Bar, string: number, beat: Beat, ignore: Set<Note>): boolean {
  for (const voice of bar.voices) {
    for (const other of voice.beats) {
      if (startOf(other) >= endOf(beat) || startOf(beat) >= endOf(other)) continue;
      if (other.notes.some((n) => n.string === string && !ignore.has(n))) return false;
    }
  }
  return true;
}

/**
 * The mean fret above 0 of the nearest earlier beat in the voice that has one;
 * 0 without. A fret past MAX_FRET is an unplayable note, not where the hand is.
 */
export function anchorBefore(beat: Beat): number {
  for (let b = beat.previousBeat; b; b = b.previousBeat) {
    const frets = b.notes.filter((n) => n.string >= 1 && n.fret > 0 && n.fret <= MAX_FRET).map((n) => n.fret);
    if (frets.length) return frets.reduce((sum, f) => sum + f, 0) / frets.length;
  }
  return 0;
}

/** Open-string pitches by alphaTab string number, 1 being the lowest. */
export const openPitches = (tuning: number[]) => (string: number) => tuning[tuning.length - string];

/**
 * Strings and frets for the notes of one beat: the cheapest assignment of
 * distinct free strings, or null for a note none can play.
 */
function assign(bar: Bar, beat: Beat, notes: Note[], pitches: number[], tuning: number[]): (number | null)[] {
  const open = openPitches(tuning);
  const ignore = new Set(notes);
  const candidates = pitches.map((pitch) => {
    const strings: number[] = [];
    for (let s = tuning.length; s >= 1; s--) {
      const fret = pitch - open(s);
      if (fret >= 0 && fret <= MAX_FRET && isFree(bar, s, beat, ignore)) strings.push(s);
    }
    return strings;
  });
  const anchor = anchorBefore(beat);
  let best: (number | null)[] = notes.map(() => null);
  let bestCost = Infinity;
  const chosen: (number | null)[] = [];
  const cost = () => {
    const frets = chosen.flatMap((s, i) => (s === null ? [] : [pitches[i] - open(s)]));
    return positionCost(frets, anchor) + UNPLACED * chosen.filter((s) => s === null).length;
  };
  const search = (i: number) => {
    if (cost() >= bestCost) return;
    if (i === notes.length) {
      bestCost = cost();
      best = [...chosen];
      return;
    }
    for (const s of candidates[i]) {
      if (chosen.includes(s)) continue;
      chosen.push(s);
      search(i + 1);
      chosen.pop();
    }
    chosen.push(null);
    search(i + 1);
    chosen.pop();
  };
  search(0);
  return best;
}

/** The free string whose open pitch is nearest below `pitch`, else any such string, else the lowest. */
function fallbackString(bar: Bar, beat: Beat, pitch: number, tuning: number[], taken: Set<number>): number {
  const open = openPitches(tuning);
  const below = (free: boolean) => {
    let found: number | null = null;
    for (let s = 1; s <= tuning.length; s++) {
      if (open(s) > pitch || (free && (taken.has(s) || !isFree(bar, s, beat, new Set())))) continue;
      if (found === null || open(s) > open(found)) found = s;
    }
    return found;
  };
  return below(true) ?? below(false) ?? 1;
}

const pianoPitch = (note: Note) => note.octave * 12 + note.tone;

/**
 * alphaTab finds a beat's note on a string through a lookup that only
 * `addNote` fills; after strings change, the notes go in again, in order.
 */
export function restring(beat: Beat): void {
  const notes = [...beat.notes];
  for (const note of notes) beat.removeNote(note);
  // removeNote forgets only a note's current string; alphaTab 1.6.1 keeps the
  // lookup in this internal field.
  (beat as unknown as { noteStringLookup: Map<number, Note> }).noteStringLookup.clear();
  for (const note of notes) beat.addNote(note);
}

/**
 * Gives guitar parts that have only pitches, as MusicXML often does, strings
 * and frets. Returns the notes no string could play, per track.
 */
export function fingerUnstrung(score: Score, settings = new alphaTab.Settings()): Map<number, NoteMark[]> {
  const marks = new Map<number, NoteMark[]>();
  const fingered: number[] = [];
  for (const [index, track] of score.tracks.entries()) {
    const staff = track.staves[0];
    if (staff.isPercussion || !isGuitar(track)) continue;
    const unstrung = staff.bars.some((bar) => bar.voices.some((v) => v.beats.some((b) => b.notes.some((n) => n.string < 0))));
    if (!unstrung) continue;
    if (staff.tuning.length === 0) staff.stringTuning.tunings = [...STANDARD_E];
    staff.showStandardNotation = true;
    staff.showTablature = true;
    marks.set(index, fingerStaff(staff));
    fingered.push(index);
  }
  if (fingered.length) finishEdit(score, { track: fingered[0], bar: 0, voice: 0, beat: 0, string: 1 }, settings);
  return new Map([...marks].filter(([, m]) => m.length > 0));
}

function fingerStaff(staff: alphaTab.model.Staff): NoteMark[] {
  const tuning = staff.tuning;
  const open = openPitches(tuning);
  const unplayable: NoteMark[] = [];
  for (const bar of staff.bars) {
    for (const voice of bar.voices) {
      for (const beat of voice.beats) {
        // Before the beat's other notes choose, so they keep off the tied string.
        for (const note of beat.notes) {
          if (note.string < 0 && note.isTieDestination && note.tieOrigin && note.tieOrigin.string >= 1) {
            note.string = note.tieOrigin.string;
            note.fret = note.tieOrigin.fret;
          }
        }
        const notes = beat.notes.filter((n) => n.string < 0);
        const pitches = notes.map(pianoPitch);
        const strings = assign(bar, beat, notes, pitches, tuning);
        const taken = new Set(beat.notes.filter((n) => n.string >= 1).map((n) => n.string));
        for (const s of strings) if (s !== null) taken.add(s);
        for (const [i, note] of notes.entries()) {
          const pitch = pitches[i];
          let string = strings[i];
          if (string === null) {
            string = fallbackString(bar, beat, pitch, tuning, taken);
            taken.add(string);
            unplayable.push({ bar: bar.index, voice: voice.index, beat: beat.index, string, kind: 'unplayable' });
          }
          note.string = string;
          note.fret = Math.max(0, pitch - open(string));
        }
        restring(beat);
      }
    }
  }
  return unplayable;
}
