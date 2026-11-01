import * as alphaTab from '@coderline/alphatab';

import type { ChordSpec, EditPosition } from '../protocol';
import { chordName, parseChordName } from './chord_names';
import { chordPositions, openStringsOf } from './chord_positions';
import { finishEdit } from './finish';
import { idSource } from './ids';
import { beatOf, staffOf } from './position';

type Score = alphaTab.model.Score;
const defaultSettings = new alphaTab.Settings();

/** Writes one of `spec`'s positions on the cursor's beat, replacing its notes; the cursor stays. */
export function setChord(score: Score, at: EditPosition, spec: ChordSpec, frets: number[], settings = defaultSettings): EditPosition {
  const staff = staffOf(score, at);
  const position = chordPositions(spec, openStringsOf(staff)).find((p) => p.frets.join() === frets.join());
  if (!position) throw new Error('not a position of this chord');
  const beat = beatOf(score, at);
  for (const note of [...beat.notes]) beat.removeNote(note);
  const ids = idSource(score);
  frets.forEach((fret, i) => {
    if (fret < 0) return;
    const note = new alphaTab.model.Note();
    note.id = ids.note();
    note.string = i + 1;
    note.fret = fret;
    beat.addNote(note);
  });
  const chord = new alphaTab.model.Chord();
  chord.name = chordName(spec);
  chord.strings = [...frets].reverse();
  chord.firstFret = position.open ? 1 : position.lowestFret;
  // The sheet shows the name only.
  chord.showDiagram = false;
  beat.chordId = chordId(staff, chord);
  beat.isEmpty = false;
  finishEdit(score, at, settings);
  return at;
}

/** An identical chord's id, or the lowest free number: Guitar Pro numbers its chords. */
function chordId(staff: alphaTab.model.Staff, chord: alphaTab.model.Chord): string {
  for (const [id, other] of staff.chords ?? []) {
    if (other.name === chord.name && other.strings.join() === chord.strings.join()) return id;
  }
  let n = 0;
  while (staff.chords?.has(`${n}`)) n++;
  staff.addChord(`${n}`, chord);
  return `${n}`;
}

/** The cursor beat's chord, with its symbol when DuoScore can read the name. */
export function chordAt(beat: alphaTab.model.Beat): { name: string; spec: ChordSpec | null } | null {
  const chord = beat.chord;
  return chord ? { name: chord.name, spec: parseChordName(chord.name) } : null;
}

/** Low string first, −1 where the beat has no note. */
export function fretsAt(beat: alphaTab.model.Beat): number[] {
  const strings = beat.voice.bar.staff.tuning.length;
  const frets = new Array<number>(strings).fill(-1);
  for (const note of beat.notes) if (note.string >= 1 && note.string <= strings) frets[note.string - 1] = note.fret;
  return frets;
}
