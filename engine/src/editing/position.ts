import type * as alphaTab from '@coderline/alphatab';

import type { EditPosition } from '../protocol';

export type Direction = 'left' | 'right' | 'up' | 'down';

export const staffOf = (score: alphaTab.model.Score, at: EditPosition) => score.tracks[at.track].staves[0];

export const barOf = (score: alphaTab.model.Score, at: EditPosition) => staffOf(score, at).bars[at.bar];

export const voiceOf = (score: alphaTab.model.Score, at: EditPosition) => barOf(score, at).voices[at.voice];

export const beatOf = (score: alphaTab.model.Score, at: EditPosition) => voiceOf(score, at).beats[at.beat];

/** The nearest position that exists in the song. */
export function clampPosition(score: alphaTab.model.Score, at: EditPosition): EditPosition {
  const clamp = (value: number, max: number) => Math.max(0, Math.min(value, max));
  const track = clamp(at.track, score.tracks.length - 1);
  const staff = score.tracks[track].staves[0];
  const bar = clamp(at.bar, staff.bars.length - 1);
  const voice = clamp(at.voice, staff.bars[bar].voices.length - 1);
  const beat = clamp(at.beat, staff.bars[bar].voices[voice].beats.length - 1);
  const string = Math.max(1, Math.min(at.string, staff.tuning.length));
  return { track, bar, voice, beat, string };
}
