import * as alphaTab from '@coderline/alphatab';

import { dropRenderedByLine } from './rendered_by';

type Score = alphaTab.model.Score;

export const A4 = { width: 595, height: 842, margin: 36 };

const SCALE = 0.75;
const PAGE_NUMBER_FROM_BOTTOM = 20;

/** A header block or staff system as alphaTab's SVG renderer draws it. */
export type Part = { svg: string; y: number; height: number };

/** The part indexes on each page, in order; a part never splits. */
export function paginate(parts: { y: number; height: number }[], contentHeight: number): number[][] {
  const pages: number[][] = [];
  let pageStart = 0;
  for (const [index, part] of parts.entries()) {
    const page = pages.at(-1);
    if (page && part.y + part.height - pageStart <= contentHeight) {
      page.push(index);
    } else {
      pages.push([index]);
      pageStart = part.y;
    }
  }
  return pages;
}

/** Renders `track` with its own renderer, so the one on screen is untouched. */
export function renderParts(score: Score, track: number, staveProfile: alphaTab.StaveProfile): Part[] {
  dropRenderedByLine();
  const settings = new alphaTab.Settings();
  settings.core.engine = 'svg';
  settings.core.enableLazyLoading = false;
  settings.display.layoutMode = alphaTab.LayoutMode.Page;
  settings.display.staveProfile = staveProfile;
  settings.display.scale = SCALE;
  const renderer = new alphaTab.rendering.ScoreRenderer(settings);
  renderer.width = A4.width - 2 * A4.margin;
  const parts: Part[] = [];
  let failure: unknown = null;
  renderer.partialRenderFinished.on((r) => parts.push({ svg: String(r.renderResult), y: r.y, height: r.height }));
  renderer.error.on((e) => (failure = e));
  renderer.renderScore(score, [track]);
  if (failure) throw failure;
  return parts.sort((a, b) => a.y - b.y);
}

/** One self-contained HTML document per A4 page of `track`. */
export function printPages(score: Score, track: number, staveProfile: alphaTab.StaveProfile, fontUrl: string): string[] {
  const parts = renderParts(score, track, staveProfile);
  const pages = paginate(parts, A4.height - 2 * A4.margin);
  return pages.map((indexes, i) => {
    const top = parts[indexes[0]].y;
    const body = indexes
      .map((index) => {
        const part = parts[index];
        return `<div style="position:absolute;left:${A4.margin}px;top:${A4.margin + part.y - top}px">${part.svg}</div>`;
      })
      .join('');
    return pageDocument(body, `${i + 1} / ${pages.length}`, fontUrl);
  });
}

function pageDocument(body: string, pageNumber: string, fontUrl: string): string {
  // The `.at` rule is the one alphaTab injects on its own pages; 34px is its
  // Environment.MusicFontSize, which it does not export.
  return `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=${A4.width}, initial-scale=1">
<style>
@font-face { font-family: 'alphaTab'; src: url(${JSON.stringify(fontUrl)}) format('woff2'); font-weight: normal; font-style: normal; font-display: block; }
.at { font-family: 'alphaTab'; font-style: normal; font-weight: normal; font-variant: normal; line-height: 1; font-size: 34px; overflow: visible !important; }
.at-surface-svg text { dominant-baseline: central; white-space: pre; }
html, body { margin: 0; padding: 0; background: #fff; }
body { position: relative; width: ${A4.width}px; height: ${A4.height}px; overflow: hidden; }
.page-number { position: absolute; left: 0; right: 0; bottom: ${PAGE_NUMBER_FROM_BOTTOM}px; text-align: center; font: 9px Georgia, serif; }
</style></head><body>${body}<div class="page-number">${pageNumber}</div></body></html>`;
}
