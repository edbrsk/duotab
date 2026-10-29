import type * as alphaTab from '@coderline/alphatab';

/**
 * Ids for objects added to `score`. alphaTab numbers beats, notes, voices and
 * bars from global counters that every import resets (the library's summaries,
 * undo), so a plain `new Beat()` can share an id with a beat already in the
 * song, and alphaTab's layout lookup, keyed by id, then finds the wrong beat.
 */
export function idSource(score: alphaTab.model.Score) {
  let beat = -1;
  let note = -1;
  let voice = -1;
  let bar = -1;
  for (const track of score.tracks) {
    for (const staff of track.staves) {
      for (const b of staff.bars) {
        bar = Math.max(bar, b.id);
        for (const v of b.voices) {
          voice = Math.max(voice, v.id);
          for (const bt of v.beats) {
            beat = Math.max(beat, bt.id);
            for (const n of bt.notes) note = Math.max(note, n.id);
          }
        }
      }
    }
  }
  return {
    beat: () => ++beat,
    note: () => ++note,
    voice: () => ++voice,
    bar: () => ++bar,
  };
}

export type IdSource = ReturnType<typeof idSource>;
