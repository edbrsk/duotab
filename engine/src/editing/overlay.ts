import type * as alphaTab from '@coderline/alphatab';

import type { BarIssue, EditPosition } from '../protocol';
import { describeOff } from './bar_check';
import { layoutOf, tabLineY } from './hit_test';

type Rect = { x: number; y: number; w: number; h: number };
type Renderer = { boundsLookup: alphaTab.rendering.BoundsLookup | null };

const CURSOR_WIDTH = 14;

/** A box around the fret position the cursor is on, in layout coordinates. */
export function cursorRect(renderer: Renderer, score: alphaTab.model.Score, at: EditPosition): Rect | null {
  const bar = score.tracks[at.track]?.staves[0].bars[at.bar];
  const beat = bar?.voices[at.voice]?.beats[at.beat];
  const lookup = renderer.boundsLookup;
  if (!bar || !beat || !lookup) return null;
  const line = tabLineY(layoutOf(renderer), bar, at.string);
  if (!line) return null;
  // An empty beat is not drawn; the cursor then sits at the start of its bar.
  const x = lookup.findBeat(beat)?.onNotesX ?? (lookup.findMasterBarByIndex(at.bar)?.realBounds.x ?? 0) + CURSOR_WIDTH;
  return { x: x - CURSOR_WIDTH / 2, y: line.y - line.spacing / 2, w: CURSOR_WIDTH, h: line.spacing };
}

export function issueRect(renderer: Renderer, bar: number): Rect | null {
  const bounds = renderer.boundsLookup?.findMasterBarByIndex(bar)?.visualBounds;
  return bounds ? { x: bounds.x, y: bounds.y, w: bounds.w, h: bounds.h } : null;
}

const place = (element: HTMLElement, rect: Rect) => {
  Object.assign(element.style, { left: `${rect.x}px`, top: `${rect.y}px`, width: `${rect.w}px`, height: `${rect.h}px` });
};

/** Redraws the edit cursor and the bar-check tints inside `container`. */
export function drawOverlay(
  container: HTMLElement,
  renderer: Renderer,
  score: alphaTab.model.Score,
  at: EditPosition | null,
  issues: BarIssue[],
): void {
  for (const old of container.querySelectorAll('.dt-edit-cursor, .dt-bar-issue')) old.remove();
  for (const bar of new Set(issues.map((i) => i.bar))) {
    const rect = issueRect(renderer, bar);
    if (!rect) continue;
    const tint = document.createElement('div');
    tint.className = 'dt-bar-issue';
    tint.dataset.msg = issues
      .filter((i) => i.bar === bar)
      .map((i) => describeOff(i.ticksOff))
      .join(' · ');
    place(tint, rect);
    container.appendChild(tint);
  }
  const rect = at && cursorRect(renderer, score, at);
  if (rect) {
    const cursor = document.createElement('div');
    cursor.className = 'dt-edit-cursor';
    place(cursor, rect);
    container.appendChild(cursor);
  }
}
