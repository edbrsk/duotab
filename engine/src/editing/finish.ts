import * as alphaTab from '@coderline/alphatab';

import type { EditPosition } from '../protocol';
import { staffOf } from './position';

type Score = alphaTab.model.Score;
type Beat = alphaTab.model.Beat;

/** `score.finish` after an edit to the staff at `at`, so the song reads as it will from the saved copy. */
export function finishEdit(score: Score, at: EditPosition, settings: alphaTab.Settings): void {
  const staff = staffOf(score, at);
  // alphaTab only fills a tie, slide or hammer-on link that is unset, and
  // never clears the arcs drawn for them, so a link to a deleted note, past a
  // new one or turned off would survive; a re-import rebuilds them all from
  // the flags.
  for (const bar of staff.bars) {
    for (const voice of bar.voices) {
      for (const beat of voice.beats) {
        beat.isEffectSlurOrigin = false;
        beat.effectSlurOrigin = null;
        beat.effectSlurDestination = null;
        for (const note of beat.notes) {
          note.isEffectSlurOrigin = false;
          note.hasEffectSlur = false;
          note.effectSlurOrigin = null;
          note.effectSlurDestination = null;
          note.tieOrigin = null;
          note.tieDestination = null;
          note.slideTarget = null;
          note.slideOrigin = null;
          note.hammerPullOrigin = null;
          note.hammerPullDestination = null;
        }
      }
    }
  }
  const moved = keepFermatasOnTheirBeats(score, staff);
  score.finish(settings);
  // Tracks that finished before the owner's did not get the fermata yet.
  for (const masterBar of moved) {
    for (const beat of beatsOf(score, masterBar.index)) beat.fermata = masterBar.getFermata(beat);
  }
}

function* beatsOf(score: Score, bar: number): Generator<Beat> {
  for (const track of score.tracks) {
    for (const staff of track.staves) {
      for (const voice of staff.bars[bar]?.voices ?? []) yield* voice.beats;
    }
  }
}

/**
 * The bar holds fermatas by tick, and `score.finish` copies them onto every
 * beat at that tick in every track. An edit that moves beats would leave the
 * fermata at the old tick and add one at the new. Each fermata belongs to the
 * edited staff's beat at its tick, in the lowest voice; only that beat keeps it
 * through `finish`.
 */
function keepFermatasOnTheirBeats(score: Score, staff: alphaTab.model.Staff): alphaTab.model.MasterBar[] {
  const moved: alphaTab.model.MasterBar[] = [];
  for (const bar of staff.bars) {
    const masterBar = bar.masterBar;
    const owners = new Map<number, Beat>();
    for (const voice of bar.voices) {
      for (const beat of voice.beats) {
        if (beat.fermata && !owners.has(beat.playbackStart)) owners.set(beat.playbackStart, beat);
      }
    }
    if (owners.size === 0 && !masterBar.fermata?.size) continue;
    const elsewhere = [...(masterBar.fermata ?? [])].filter(([tick]) => !owners.has(tick));
    const owned = new Set(owners.values());
    for (const beat of beatsOf(score, masterBar.index)) if (!owned.has(beat)) beat.fermata = null;
    masterBar.fermata = null;
    for (const [tick, fermata] of elsewhere) masterBar.addFermata(tick, fermata);
    moved.push(masterBar);
  }
  return moved;
}
