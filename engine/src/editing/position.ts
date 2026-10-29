import type * as alphaTab from '@coderline/alphatab';

import type { EditPosition } from '../protocol';

export type Direction = 'left' | 'right' | 'up' | 'down';

export const staffOf = (score: alphaTab.model.Score, at: EditPosition) => score.tracks[at.track].staves[0];

export const barOf = (score: alphaTab.model.Score, at: EditPosition) => staffOf(score, at).bars[at.bar];

export const voiceOf = (score: alphaTab.model.Score, at: EditPosition) => barOf(score, at).voices[at.voice];

export const beatOf = (score: alphaTab.model.Score, at: EditPosition) => voiceOf(score, at).beats[at.beat];
