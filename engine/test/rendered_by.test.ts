import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { dropRenderedByLine } from '../src/rendered_by';
import { longRiff, score } from './fixtures';

function drawn(layoutMode: alphaTab.LayoutMode): string {
  const settings = new alphaTab.Settings();
  settings.core.engine = 'svg';
  settings.core.enableLazyLoading = false;
  settings.display.layoutMode = layoutMode;
  const renderer = new alphaTab.rendering.ScoreRenderer(settings);
  renderer.width = 800;
  const svgs: string[] = [];
  renderer.partialRenderFinished.on((r) => svgs.push(String(r.renderResult)));
  renderer.renderScore(score(longRiff), [0]);
  return svgs.join('');
}

const layouts = [alphaTab.LayoutMode.Page, alphaTab.LayoutMode.Horizontal];

test("the sheet has no 'rendered by alphaTab' line", () => {
  for (const layout of layouts) expect(drawn(layout)).toContain('rendered by alphaTab');

  dropRenderedByLine();
  dropRenderedByLine();

  for (const layout of layouts) {
    const svg = drawn(layout);
    expect(svg).not.toContain('rendered by alphaTab');
    expect(svg).toContain('= 140');
  }
});
