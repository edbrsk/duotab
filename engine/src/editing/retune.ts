import * as alphaTab from '@coderline/alphatab';

import { anchorBefore, isFree, MAX_FRET, type NoteMark, openPitches, positionCost, restring } from './fingering';
import { finishEdit } from './finish';
import { isGuitar } from './tracks';

type Score = alphaTab.model.Score;
type Note = alphaTab.model.Note;

type Beat = alphaTab.model.Beat;

type Placing = {
  note: Note;
  pitch: number;
  mapped: number | null;
  oldFret: number;
  oldOpen: number;
  natural: boolean;
};

const playable = (fret: number) => fret >= 0 && fret <= MAX_FRET;

const scratch = new alphaTab.model.Note();
scratch.string = 1;
scratch.harmonicType = alphaTab.model.HarmonicType.Natural;
/** Semitones above the open string that a natural harmonic at `node` sounds; 0 where none rings. */
const nodePitch = (node: number) => {
  scratch.harmonicValue = node;
  return scratch.harmonicPitch;
};

const NODES = Array.from({ length: MAX_FRET }, (_, i) => i + 1);

const startsBefore = (a: Beat, b: Beat) =>
  a.voice.bar.index < b.voice.bar.index || (a.voice.bar.index === b.voice.bar.index && a.playbackStart < b.playbackStart);

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
          const natural = note.harmonicType === alphaTab.model.HarmonicType.Natural && nodePitch(note.harmonicValue) > 0;
          // A natural harmonic sounds at its node, not at its fret.
          const above = natural ? nodePitch(note.harmonicValue) : note.fret;
          const placing = {
            note,
            pitch: oldOpen(note.string) + above + 12 * octave,
            mapped: mapString(note.string),
            oldFret: note.fret,
            oldOpen: oldOpen(note.string),
            natural,
          };
          placings.set(note, placing);
          order.push(placing);
        }
      }
    }
  }
  /** The fret, or a natural harmonic's node, that sounds `p` on string `s`; null where none can. */
  const fretFor = (p: Placing, s: number): number | null => {
    if (!p.natural) {
      const fret = p.pitch - newOpen(s);
      return playable(fret) ? fret : null;
    }
    const nodes = [p.note.harmonicValue, ...NODES];
    return nodes.find((node) => nodePitch(node) > 0 && newOpen(s) + nodePitch(node) === p.pitch) ?? null;
  };
  const setFret = (p: Placing, fret: number) => {
    p.note.fret = fret;
    if (p.natural) p.note.harmonicValue = fret;
  };
  const out = (p: Placing) => p.mapped === null || fretFor(p, p.mapped) === null;
  // Out-of-range notes occupy no string until they are placed.
  for (const p of order) {
    p.note.string = out(p) ? 0 : p.mapped!;
    if (!out(p)) setFret(p, fretFor(p, p.mapped!)!);
  }
  const links: [Note, Note][] = order.flatMap(({ note }) =>
    [note.tieDestination, note.hammerPullDestination, note.slideTarget].flatMap((d) => (d ? [[note, d] as [Note, Note]] : [])),
  );
  // alphaTab relinks a tie, hammer-on or slide to the nearest note on its
  // string in the voice, so nothing may sit on that string between the two.
  const crossesLink = (p: Placing, s: number, group: Set<Note>) =>
    links.some(
      ([from, to]) =>
        !group.has(from) &&
        from.string === s &&
        to.string === s &&
        from.beat.voice.index === p.note.beat.voice.index &&
        startsBefore(from.beat, p.note.beat) &&
        startsBefore(p.note.beat, to.beat),
    );
  const blocksOwnLinks = (s: number, group: Set<Note>) =>
    links.some(([from, to]) => {
      if (!group.has(from) || !group.has(to)) return false;
      for (let b = from.beat.nextBeat; b && b !== to.beat; b = b.nextBeat) {
        if (b.notes.some((n) => n.string === s && !group.has(n))) return true;
      }
      return false;
    });

  const groups = linkedGroups(order, placings);
  const marks: NoteMark[] = [];
  const mark = (p: Placing, kind: NoteMark['kind']) => {
    const beat = p.note.beat;
    marks.push({ bar: beat.voice.bar.index, voice: beat.voice.index, beat: beat.index, string: p.note.string, kind });
  };
  const place = (p: Placing, string: number) => {
    p.note.string = string;
    setFret(p, fretFor(p, string)!);
    if (string !== p.mapped) mark(p, 'moved');
  };
  const cheapest = (members: Placing[]) => {
    const ignore = new Set(members.map((m) => m.note));
    let best: number | null = null;
    let bestCost = Infinity;
    for (const s of strings) {
      const frets = members.map((m) => fretFor(m, s));
      if (frets.some((f) => f === null)) continue;
      if (!members.every((m) => isFree(m.note.beat.voice.bar, s, m.note.beat, ignore))) continue;
      if (members.some((m) => crossesLink(m, s, ignore)) || blocksOwnLinks(s, ignore)) continue;
      const cost = positionCost(frets as number[], anchorBefore(members[0].note.beat));
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
