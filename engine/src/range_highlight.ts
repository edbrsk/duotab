type Range = { startTick: number; endTick: number };

export interface HighlightApi {
  readonly playbackRange: Range | null;
  readonly postRenderFinished: { on(handler: () => void): () => void };
  updateSelectionCursor(range: Range | null): void;
}

/**
 * alphaTab redraws only selections made with its own mouse handling after a
 * render; a range set from code (a saved loop, a long press) would vanish on
 * every redraw while still limiting playback.
 */
export function keepRangeHighlighted(api: HighlightApi): void {
  api.postRenderFinished.on(() => api.updateSelectionCursor(api.playbackRange));
}
