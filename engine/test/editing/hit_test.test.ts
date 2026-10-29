import * as alphaTab from '@coderline/alphatab';
import { beforeAll, expect, test } from 'vitest';

import { hitTest } from '../../src/editing/hit_test';
import { cursorRect, issueRect } from '../../src/editing/overlay';
import { fourQuarters, score } from '../fixtures';

let renderer: alphaTab.rendering.ScoreRenderer;
let song: alphaTab.model.Score;

beforeAll(async () => {
  const settings = new alphaTab.Settings();
  settings.core.engine = 'svg';
  settings.core.enableLazyLoading = false;
  settings.display.staveProfile = alphaTab.StaveProfile.ScoreTab;
  renderer = new alphaTab.rendering.ScoreRenderer(settings);
  renderer.width = 800;
  await new Promise<void>((resolve) => {
    renderer.renderFinished.on(() => resolve());
    song = score(fourQuarters);
    renderer.renderScore(song, [0]);
  });
});

// The same alphaTab 1.6.1 layout internals hit_test.ts reads, walked here independently.
type Line = { y: (line: number) => number };
function staffLines(kind: 'TabBarRenderer' | 'ScoreBarRenderer'): Line {
  const system = (renderer as unknown as { layout: { _systems: any[] } }).layout._systems[0];
  for (const group of system.staves)
    for (const staff of group.staves) {
      const bar = staff.barRenderers[0];
      if (bar.constructor.name === kind)
        return { y: (line) => system.y + system.topPadding + staff.y + bar.y + bar.getLineY(line) };
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

test('the cursor sits on its string at its beat', () => {
  const tab = staffLines('TabBarRenderer');
  const rect = cursorRect(renderer, song, { track: 0, bar: 0, voice: 0, beat: 1, string: 6 })!;
  expect(rect.y + rect.h / 2).toBeCloseTo(tab.y(0));
  expect(rect.x + rect.w / 2).toBeCloseTo(beatX(1));
});

test("an issue covers its bar", () => {
  const bar = renderer.boundsLookup!.findMasterBarByIndex(1)!.visualBounds;
  expect(issueRect(renderer, 1)).toEqual({ x: bar.x, y: bar.y, w: bar.w, h: bar.h });
});

test('taps land on the drawn string on every line of music', async () => {
  const settings = new alphaTab.Settings();
  settings.core.engine = 'svg';
  settings.core.enableLazyLoading = false;
  settings.core.includeNoteBounds = true;
  settings.display.staveProfile = alphaTab.StaveProfile.ScoreTab;
  const many = score(String.raw`\title "Many"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
` + Array(16).fill('0.6.4 2.5.4 3.4.4 5.3.4').join(' | '));
  const wide = new alphaTab.rendering.ScoreRenderer(settings);
  wide.width = 800;
  await new Promise<void>((resolve) => {
    wide.renderFinished.on(() => resolve());
    wide.renderScore(many, [0]);
  });
  // alphaTab's own note bounds, independent of hit_test: the last BeatBounds of a beat is its tab staff.
  for (const barIndex of [0, 12]) {
    const beats = many.tracks[0].staves[0].bars[barIndex].voices[0].beats;
    for (const [beat, string] of [[0, 1], [1, 2], [2, 3], [3, 4]] as const) {
      const tab = wide.boundsLookup!.findBeats(beats[beat])!.at(-1)!;
      const head = tab.notes![0].noteHeadBounds;
      const hit = hitTest(wide, 0, 0, tab.onNotesX, head.y + head.h / 2);
      expect(hit, `bar ${barIndex} beat ${beat}`).toMatchObject({ bar: barIndex, beat, string });
    }
  }
});

// On the page alphaTab wraps its renderer (ScoreRendererWrapper): bounds are
// forwarded, the layout is only on `instance`.
test('taps and the cursor work through the renderer wrapper the page uses', () => {
  const wrapper = { boundsLookup: renderer.boundsLookup, instance: renderer };
  const tab = staffLines('TabBarRenderer');
  expect(hitTest(wrapper, 0, 0, beatX(1), tab.y(0))?.string).toBe(6);
  expect(cursorRect(wrapper, song, { track: 0, bar: 0, voice: 0, beat: 1, string: 6 })).not.toBeNull();
});
