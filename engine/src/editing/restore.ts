import type * as alphaTab from '@coderline/alphatab';

/**
 * Tones and staff views are practice settings, not edits: a song restored
 * by undo keeps the ones chosen since, as the panels show them.
 */
export function carryPlaybackSettings(current: alphaTab.model.Score, restored: alphaTab.model.Score): void {
  for (const [index, track] of current.tracks.entries()) {
    const target = restored.tracks[index];
    if (!target) continue;
    target.playbackInfo.program = track.playbackInfo.program;
    target.staves[0].showStandardNotation = track.staves[0].showStandardNotation;
    target.staves[0].showTablature = track.staves[0].showTablature;
  }
}

type Range = { startTick: number; endTick: number };

/** As in Guitar Pro: a tap inside the loop keeps it, a tap elsewhere clears it. */
export function rangeAfterTap<R extends Range>(range: R | null, tick: number): R | null {
  return range && tick >= range.startTick && tick < range.endTick ? range : null;
}
