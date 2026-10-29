import type * as alphaTab from '@coderline/alphatab';

import type { BarIssue } from '../protocol';

const WHOLE = 3840;

export function checkBars(score: alphaTab.model.Score, track: number): BarIssue[] {
  const issues: BarIssue[] = [];
  for (const bar of score.tracks[track].staves[0].bars) {
    const expected = bar.masterBar.calculateDuration();
    for (const voice of bar.voices) {
      // A voice made only of empty beats is unused, as in Guitar Pro.
      if (voice.beats.every((b) => b.isEmpty)) continue;
      const ticks = voice.beats.reduce((t, b) => t + b.playbackDuration, 0);
      if (ticks !== expected) issues.push({ bar: bar.index, voice: voice.index, ticksOff: ticks - expected });
    }
  }
  return issues;
}

const VULGAR: Record<string, string> = {
  '1/2': '½',
  '1/4': '¼',
  '3/4': '¾',
  '1/8': '⅛',
  '3/8': '⅜',
  '5/8': '⅝',
  '7/8': '⅞',
};

const gcd = (a: number, b: number): number => (b === 0 ? a : gcd(b, a % b));

export function describeOff(ticksOff: number): string {
  const ticks = Math.abs(ticksOff);
  const divisor = gcd(ticks, WHOLE);
  const fraction = `${ticks / divisor}/${WHOLE / divisor}`;
  return `${VULGAR[fraction] ?? fraction} ${ticksOff < 0 ? 'short' : 'long'}`;
}
