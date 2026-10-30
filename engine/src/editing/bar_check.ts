import type * as alphaTab from '@coderline/alphatab';

import type { BarIssue } from '../protocol';

const WHOLE = 3840;

export function checkBars(score: alphaTab.model.Score, track: number): BarIssue[] {
  const issues: BarIssue[] = [];
  for (const bar of score.tracks[track].staves[0].bars) {
    // A pickup is short by design, and free time has no length to keep.
    if (bar.masterBar.isAnacrusis || bar.masterBar.isFreeTime) continue;
    const expected = bar.masterBar.calculateDuration();
    for (const voice of bar.voices) {
      // A voice made only of empty beats is unused, as in Guitar Pro.
      if (voice.beats.every((b) => b.isEmpty)) continue;
      // A grace note takes its playback time from the beat before it, which can be in the bar before.
      const ticks = voice.beats.reduce((t, b) => t + b.displayDuration, 0);
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
