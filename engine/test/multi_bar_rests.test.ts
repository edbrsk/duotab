import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { drawEveryBar, withFileRests } from '../src/multi_bar_rests';
import { moveTrack } from '../src/editing/tracks';
import { score } from './fixtures';

// Bars 2–4 are empty: with the file's multi-bar rests on, they draw as one.
function restingSong() {
  const s = score(String.raw`\title "Rests"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
0.6.1 | r.1 | r.1 | r.1 | 0.6.1`);
  s.stylesheet.perTrackMultiBarRest = new Set([0]);
  return s;
}

function barsDrawn(s: alphaTab.model.Score): number {
  const settings = new alphaTab.Settings();
  settings.core.engine = 'svg';
  settings.core.enableLazyLoading = false;
  const renderer = new alphaTab.rendering.ScoreRenderer(settings);
  renderer.width = 1200;
  renderer.renderScore(s, [0]);
  return renderer.boundsLookup!.staffSystems.flatMap((system) => system.bars).length;
}

test("the file's multi-bar rests draw as one bar until told otherwise", () => {
  expect(barsDrawn(restingSong())).toBeLessThan(5);
});

test('every bar is drawn on its own', () => {
  const s = restingSong();
  drawEveryBar(s);
  expect(barsDrawn(s)).toBe(5);
});

test("a saved file keeps the file's multi-bar rests", () => {
  const s = restingSong();
  drawEveryBar(s);
  const bytes = withFileRests(() => new alphaTab.exporter.Gp7Exporter().export(s, new alphaTab.Settings()));
  const reopened = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, new alphaTab.Settings());
  expect(reopened.stylesheet.perTrackMultiBarRest?.has(0)).toBe(true);
});

test('undo snapshots keep them too', () => {
  const s = restingSong();
  drawEveryBar(s);
  const copy = alphaTab.model.JsonConverter.jsObjectToScore(alphaTab.model.JsonConverter.scoreToJsObject(s));
  expect([...(copy.stylesheet.perTrackMultiBarRest ?? [])]).toEqual([0]);
});

test('a song with none is left alone', () => {
  const s = score(String.raw`\title "Plain"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
0.6.1`);
  drawEveryBar(s);
  expect(s.stylesheet.perTrackMultiBarRest).toBeNull();
});

test('moving a track keeps every bar drawn, and the rests with their track', () => {
  const s = score(String.raw`\title "Two"
.
\track "A" \tuning E4 B3 G3 D3 A2 E2
0.6.1 | r.1 | r.1
\track "B" \tuning E4 B3 G3 D3 A2 E2
0.6.1 | r.1 | r.1`);
  s.stylesheet.perTrackMultiBarRest = new Set([0]);
  drawEveryBar(s);
  moveTrack(s, 0, 1);
  expect(s.stylesheet.perTrackMultiBarRest!.has(1)).toBe(false);
  expect(withFileRests(() => s.stylesheet.perTrackMultiBarRest!.has(1))).toBe(true);
});
