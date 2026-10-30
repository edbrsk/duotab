import type * as alphaTab from '@coderline/alphatab';

import { barTimeline } from '../timeline';

/**
 * Tones, volumes and staff views are practice settings, not edits: a song
 * restored by undo keeps the ones chosen since, as the panels show them.
 * Tracks are matched by their primary MIDI channel, as undo can move them.
 */
export function carryPlaybackSettings(current: alphaTab.model.Score, restored: alphaTab.model.Score): void {
  const unmatched = [...current.tracks];
  for (const target of restored.tracks) {
    const at = unmatched.findIndex((t) => t.playbackInfo.primaryChannel === target.playbackInfo.primaryChannel);
    if (at < 0) continue;
    const [track] = unmatched.splice(at, 1);
    target.playbackInfo.program = track.playbackInfo.program;
    target.playbackInfo.volume = track.playbackInfo.volume;
    target.staves[0].showStandardNotation = track.staves[0].showStandardNotation;
    target.staves[0].showTablature = track.staves[0].showTablature;
  }
}

type Range = { startTick: number; endTick: number };

/** As in Guitar Pro: a tap inside the loop keeps it, a tap elsewhere clears it. */
export function rangeAfterTap<R extends Range>(range: R | null, tick: number): R | null {
  return range && tick >= range.startTick && tick < range.endTick ? range : null;
}

/** A loop survives undo or redo only while every bar starts where it did. */
export function rangeAfterRestore<R extends Range>(before: number[], after: number[], range: R | null): R | null {
  return range && before.length === after.length && before.every((tick, i) => tick === after[i]) ? range : null;
}

/**
 * Where each bar first plays, in the MIDI ticks a loop is kept in: repeats
 * and endings move these without moving where the bar is written.
 */
export function firstPassStarts(score: alphaTab.model.Score): number[] {
  return barTimeline(score).map((bar) => bar.startTick);
}
