import * as alphaTab from '@coderline/alphatab';

type Layout = { layoutAndRenderAnnotation(y: number): number };
type LayoutFactory = { createLayout(renderer: unknown): Layout };

let dropped = false;

/**
 * CoderLine agreed that DuoScore leaves alphaTab's "rendered by alphaTab" line
 * off the sheet; the Licences screen credits alphaTab instead.
 */
export function dropRenderedByLine(): void {
  if (dropped) return;
  dropped = true;
  // alphaTab keeps its layouts internal; their factories are the one way in.
  const engines = (alphaTab.Environment as unknown as { layoutEngines: Map<unknown, LayoutFactory> }).layoutEngines;
  for (const factory of engines.values()) {
    const create = factory.createLayout;
    factory.createLayout = (renderer) => {
      const layout = create(renderer);
      layout.layoutAndRenderAnnotation = (y) => y;
      return layout;
    };
  }
}
