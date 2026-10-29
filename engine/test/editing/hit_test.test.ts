import * as alphaTab from '@coderline/alphatab';
import { beforeAll, expect, test } from 'vitest';

import { hitTest } from '../../src/editing/hit_test';
import { fourQuarters, score } from '../fixtures';

let renderer: alphaTab.rendering.ScoreRenderer;

beforeAll(async () => {
  const settings = new alphaTab.Settings();
  settings.core.engine = 'svg';
  settings.core.enableLazyLoading = false;
  settings.display.staveProfile = alphaTab.StaveProfile.ScoreTab;
  renderer = new alphaTab.rendering.ScoreRenderer(settings);
  renderer.width = 800;
  await new Promise<void>((resolve) => {
    renderer.renderFinished.on(() => resolve());
    renderer.renderScore(score(fourQuarters), [0]);
  });
});

// The same alphaTab 1.6.1 layout internals hit_test.ts reads, walked here independently.
type Line = { y: (line: number) => number };
function staffLines(kind: 'TabBarRenderer' | 'ScoreBarRenderer'): Line {
  const system = (renderer as unknown as { layout: { _systems: any[] } }).layout._systems[0];
  for (const group of system.staves)
    for (const staff of group.staves) {
      const bar = staff.barRenderers[0];
      if (bar.constructor.name === kind) return { y: (line) => system.y + staff.y + bar.y + bar.getLineY(line) };
    }
  throw new Error(`no ${kind}`);
}
const beatX = (beat: number) => {
  const bounds = renderer.boundsLookup!.staffSystems[0].bars[0].bars[0].beats[beat];
  return bounds.onNotesX;
};

test('a tap on a tab line gives that string', () => {
  const tab = staffLines('TabBarRenderer');
  expect(hitTest(renderer, 0, 0, beatX(1), tab.y(0))).toEqual({ track: 0, bar: 0, voice: 0, beat: 1, string: 6 });
});

test('a tap between lines gives the nearer string', () => {
  const tab = staffLines('TabBarRenderer');
  expect(hitTest(renderer, 0, 0, beatX(1), tab.y(2) + 3)?.string).toBe(4);
});

test('a tap on the notation staff gives the beat with no string', () => {
  const notation = staffLines('ScoreBarRenderer');
  expect(hitTest(renderer, 0, 0, beatX(2), notation.y(2))).toEqual({
    track: 0,
    bar: 0,
    voice: 0,
    beat: 2,
    string: null,
  });
});

test('a tap outside the score gives null', () => {
  expect(hitTest(renderer, 0, 0, 5, 5)).toBeNull();
});
