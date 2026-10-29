import { expect, test } from 'vitest';

import { keepRangeHighlighted } from '../src/range_highlight';

test('redraws the loop range after every render', () => {
  const handlers: (() => void)[] = [];
  const drawn: unknown[] = [];
  const api = {
    playbackRange: { startTick: 960, endTick: 3840 } as { startTick: number; endTick: number } | null,
    postRenderFinished: { on: (h: () => void) => (handlers.push(h), () => {}) },
    updateSelectionCursor: (range: unknown) => drawn.push(range),
  };
  keepRangeHighlighted(api);

  handlers.forEach((h) => h());
  api.playbackRange = null;
  handlers.forEach((h) => h());

  expect(drawn).toEqual([{ startTick: 960, endTick: 3840 }, null]);
});
