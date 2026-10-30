import * as alphaTab from '@coderline/alphatab';

import { anchorBefore, isFree, MAX_FRET, type NoteMark, openPitches, positionCost, restring } from './fingering';
import { finishEdit } from './finish';
import { isGuitar } from './tracks';

type Score = alphaTab.model.Score;
type Note = alphaTab.model.Note;

type Placing = { note: Note; pitch: number; mapped: number | null; oldFret: number; oldOpen: number };

const playable = (fret: number) => fret >= 0 && fret <= MAX_FRET;

/**
 * Retunes a guitar track keeping every note's pitch; `octave` shifts them all
 * by octaves. Returns the notes moved to another string and those no string
 * can play, which keep their fret.
 */
export function retune(
  score: Score,
  trackIndex: number,
  tuning: number[],
  octave: number,
  settings = new alphaTab.Settings(),
): NoteMark[] {
  const track = score.tracks[trackIndex];
  if (!track || track.staves[0].isPercussion || !isGuitar(track)) throw new Error('only guitar tracks can be retuned');
  if (tuning.length < 1 || tuning.length > 10) throw new Error('a tuning needs 1 to 10 strings');
  if (!Number.isInteger(octave) || octave < -2 || octave > 2) throw new Error('octave must be -2 to 2');
  const staff = track.staves[0];
  const oldTuning = [...staff.tuning];
  if (octave === 0 && oldTuning.join() === tuning.join()) return [];

  const oldOpen = openPitches(oldTuning);
  const newOpen = openPitches(tuning);
  // Strings match from the top down.
  const mapString = (s: number) => {
    const fromTop = oldTuning.length - s;
    return fromTop < tuning.length ? tuning.length - fromTop : null;
  };
  const strings = Array.from({ length: tuning.length }, (_, i) => tuning.length - i);
  const nearestByPitch = (pitch: number, among: number[]) =>
    among.reduce((best, s) => (Math.abs(newOpen(s) - pitch) < Math.abs(newOpen(best) - pitch) ? s : best));

  const placings = new Map<Note, Placing>();
  const order: Placing[] = [];
  for (const bar of staff.bars) {
    for (const voice of bar.voices) {
      for (const beat of voice.beats) {
        for (const note of beat.notes) {
          if (note.string < 1) continue;
          const placing = {
            note,
            pitch: oldOpen(note.string) + note.fret + 12 * octave,
            mapped: mapString(note.string),
            oldFret: note.fret,
            oldOpen: oldOpen(note.string),
          };
          placings.set(note, placing);
          order.push(placing);
        }
      }
    }
  }
  const out = (p: Placing) => p.mapped === null || !playable(p.pitch - newOpen(p.mapped));
  // Out-of-range notes occupy no string until they are placed.
  for (const p of order) {
    p.note.string = out(p) ? 0 : p.mapped!;
    p.note.fret = out(p) ? p.oldFret : p.pitch - newOpen(p.mapped!);
  }

  const groups = linkedGroups(order, placings);
  const marks: NoteMark[] = [];
  const mark = (p: Placing, kind: NoteMark['kind']) => {
    const beat = p.note.beat;
    marks.push({ bar: beat.voice.bar.index, voice: beat.voice.index, beat: beat.index, string: p.note.string, kind });
  };
  const place = (p: Placing, string: number) => {
    p.note.string = string;
    p.note.fret = p.pitch - newOpen(string);
    if (string !== p.mapped) mark(p, 'moved');
  };
  const cheapest = (members: Placing[]) => {
    const ignore = new Set(members.map((m) => m.note));
    let best: number | null = null;
    let bestCost = Infinity;
    for (const s of strings) {
      const frets = members.map((m) => m.pitch - newOpen(s));
      if (!frets.every(playable)) continue;
      if (!members.every((m) => isFree(m.note.beat.voice.bar, s, m.note.beat, ignore))) continue;
      const cost = positionCost(frets, anchorBefore(members[0].note.beat));
      if (cost < bestCost) {
        best = s;
        bestCost = cost;
      }
    }
    return best;
  };

  for (const group of groups) {
    if (!group.some(out)) continue;
    const together = cheapest(group);
    if (together !== null) {
      for (const p of group) place(p, together);
      continue;
    }
    for (const p of group.filter(out)) {
      const alone = cheapest([p]);
      if (alone !== null) {
        place(p, alone);
      } else {
        // Two notes of a beat on one string would also tie to the wrong note.
        const beat = p.note.beat;
        const free = strings.filter((s) => isFree(beat.voice.bar, s, beat, new Set([p.note])));
        const home = p.mapped ?? nearestByPitch(p.oldOpen, strings);
        p.note.string = free.includes(home) || free.length === 0 ? home : nearestByPitch(p.oldOpen, free);
        p.note.fret = p.oldFret;
        mark(p, 'unplayable');
      }
    }
    unlinkAcrossStrings(group);
  }

  for (const p of order) {
    if (p.note.harmonicType === alphaTab.model.HarmonicType.Natural) p.note.harmonicValue = p.note.fret;
  }
  retuneChords(staff, oldTuning, tuning, octave);
  staff.stringTuning.tunings = [...tuning];
  // Tuning.finish names only tunings it knows; an old name would outlive them.
  staff.stringTuning.name = '';
  for (const bar of staff.bars) for (const voice of bar.voices) for (const beat of voice.beats) restring(beat);
  finishEdit(score, { track: trackIndex, bar: 0, voice: 0, beat: 0, string: 1 }, settings);
  return marks;
}

/** Notes joined by a tie, hammer-on/pull-off or slide, each group in time order. */
function linkedGroups(order: Placing[], placings: Map<Note, Placing>): Placing[][] {
  const root = new Map<Placing, Placing>(order.map((p) => [p, p]));
  const find = (p: Placing): Placing => {
    let r = p;
    while (root.get(r) !== r) r = root.get(r)!;
    root.set(p, r);
    return r;
  };
  for (const p of order) {
    for (const linked of [p.note.tieDestination, p.note.hammerPullDestination, p.note.slideTarget]) {
      const other = linked && placings.get(linked);
      if (other) root.set(find(other), find(p));
    }
  }
  const groups = new Map<Placing, Placing[]>();
  for (const p of order) {
    const r = find(p);
    if (!groups.has(r)) groups.set(r, []);
    groups.get(r)!.push(p);
  }
  return [...groups.values()];
}

function unlinkAcrossStrings(group: Placing[]): void {
  for (const { note } of group) {
    const apart = (other: Note | null) => other !== null && other.string !== note.string;
    if (apart(note.hammerPullDestination)) note.isHammerPullOrigin = false;
    if (apart(note.slideTarget)) note.slideOutType = alphaTab.model.SlideOutType.None;
    if (apart(note.tieDestination)) note.tieDestination!.isTieDestination = false;
  }
}

/** Chord diagrams list frets from the top string, as tunings do. */
function retuneChords(staff: alphaTab.model.Staff, oldTuning: number[], tuning: number[], octave: number): void {
  for (const chord of staff.chords?.values() ?? []) {
    let playableDiagram = true;
    const frets = tuning.map((open, i) => {
      const fret = i < oldTuning.length ? (chord.strings[i] ?? -1) : -1;
      if (fret < 0) return -1;
      const moved = fret + oldTuning[i] - open + 12 * octave;
      if (!playable(moved)) playableDiagram = false;
      return moved;
    });
    if (chord.strings.slice(tuning.length).some((f) => f >= 0)) playableDiagram = false;
    chord.strings = frets;
    if (!playableDiagram) chord.showDiagram = false;
  }
}
