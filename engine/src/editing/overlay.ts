import type * as alphaTab from '@coderline/alphatab';

import type { BarIssue, EditPosition } from '../protocol';
import type { NoteMark } from './fingering';
import { describeOff } from './bar_check';
import { layoutOf, notationLines, tabLineY } from './hit_test';

type Rect = { x: number; y: number; w: number; h: number };
type Renderer = { boundsLookup: alphaTab.rendering.BoundsLookup | null };

const CURSOR_WIDTH = 14;

/** A box around the fret position the cursor is on, in layout coordinates. */
export function cursorRect(renderer: Renderer, score: alphaTab.model.Score, at: EditPosition): Rect | null {
  const bar = score.tracks[at.track]?.staves[0].bars[at.bar];
  const beat = bar?.voices[at.voice]?.beats[at.beat];
  const lookup = renderer.boundsLookup;
  if (!bar || !beat || !lookup) return null;
  // An empty beat is not drawn; the cursor then sits at the start of its bar.
  const x = lookup.findBeat(beat)?.onNotesX ?? (lookup.findMasterBarByIndex(at.bar)?.realBounds.x ?? 0) + CURSOR_WIDTH;
  const line = tabLineY(layoutOf(renderer), bar, at.string);
  if (line) return { x: x - CURSOR_WIDTH / 2, y: line.y - line.spacing / 2, w: CURSOR_WIDTH, h: line.spacing };
  // With the tab hidden, the cursor marks the beat on the notation staff.
  const staff = notationLines(layoutOf(renderer), bar);
  if (!staff) return null;
  return { x: x - CURSOR_WIDTH / 2, y: staff.top - staff.spacing / 2, w: CURSOR_WIDTH, h: staff.bottom - staff.top + staff.spacing };
}

export function issueRect(renderer: Renderer, bar: number): Rect | null {
  const bounds = renderer.boundsLookup?.findMasterBarByIndex(bar)?.visualBounds;
  return bounds ? { x: bounds.x, y: bounds.y, w: bounds.w, h: bounds.h } : null;
}

/** Tints the size of the cursor over each marked note's tab fret. */
export function markRects(
  renderer: Renderer,
  score: alphaTab.model.Score,
  track: number,
  marks: NoteMark[],
): { rect: Rect; kind: NoteMark['kind'] }[] {
  return marks.flatMap(({ kind, ...at }) => {
    const rect = cursorRect(renderer, score, { ...at, track });
    return rect ? [{ rect, kind }] : [];
  });
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
  track: number,
  marks: NoteMark[],
): void {
  for (const old of container.querySelectorAll('.dt-edit-cursor, .dt-bar-issue, .dt-note-moved, .dt-note-unplayable')) old.remove();
  for (const { rect, kind } of markRects(renderer, score, track, marks)) {
    const tint = document.createElement('div');
    tint.className = kind === 'moved' ? 'dt-note-moved' : 'dt-note-unplayable';
    place(tint, rect);
    container.appendChild(tint);
  }
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
