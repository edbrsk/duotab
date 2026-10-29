import type * as alphaTab from '@coderline/alphatab';

export type Hit = { track: number; bar: number; voice: number; beat: number; string: number | null };

// The parts of alphaTab 1.6.1's internal layout (ScoreLayout._systems →
// StaffSystem.staves → StaffTrackGroup.staves → RenderStaff.barRenderers) that
// locate tab lines; boundsLookup has no string positions.
type BarRenderer = { bar: alphaTab.model.Bar; y: number; drawnLineCount: number; getLineY(line: number): number };
type RenderStaff = { staffId: string; y: number; barRenderers: BarRenderer[] };
type StaffSystem = { y: number; topPadding: number; staves: { staves: RenderStaff[] }[] };

type Renderer = { boundsLookup: alphaTab.rendering.BoundsLookup | null };

/**
 * The layout of a ScoreRenderer, or of the one inside the ScoreRendererWrapper
 * that `api.renderer` is on the page (alphaTab 1.6.1 internals).
 */
export function layoutOf(renderer: unknown): unknown {
  const r = renderer as { layout?: unknown; instance?: { layout?: unknown } };
  return r.layout ?? r.instance?.layout;
}

/** The beat of `voice` and the tab string under a tap, in layout coordinates. */
export function hitTest(renderer: Renderer, track: number, voice: number, x: number, y: number): Hit | null {
  const lookup = renderer.boundsLookup;
  const tapped = lookup?.getBeatAtPos(x, y);
  if (!lookup || !tapped) return null;
  const bar = tapped.voice.bar;
  if (bar.staff.track.index !== track) return null;

  const beats = bar.voices[voice]?.beats ?? [];
  let beat = 0;
  let distance = Number.POSITIVE_INFINITY;
  for (const candidate of beats) {
    const bounds = lookup.findBeat(candidate);
    if (!bounds) continue;
    const d = Math.abs(bounds.onNotesX - x);
    if (d < distance) {
      distance = d;
      beat = candidate.index;
    }
  }
  return { track, bar: bar.index, voice, beat, string: stringAt(layoutOf(renderer), bar, y) };
}

/** The tab staff drawing `bar`, with its line positions in layout coordinates. */
function tabStaff(layout: unknown, bar: alphaTab.model.Bar) {
  const systems = (layout as { _systems?: StaffSystem[] })._systems ?? [];
  for (const system of systems) {
    for (const group of system.staves) {
      for (const staff of group.staves) {
        if (staff.staffId !== 'tab') continue;
        const renderer = staff.barRenderers.find((r) => r.bar === bar);
        if (!renderer) continue;
        // alphaTab paints a system and builds its bounds offset by its topPadding.
        const lineY = (line: number) =>
          system.y + system.topPadding + staff.y + renderer.y + renderer.getLineY(line);
        return { lineY, lines: renderer.drawnLineCount, spacing: lineY(1) - lineY(0) };
      }
    }
  }
  return null;
}

// The top line is the highest string, which alphaTab numbers last.
const lineOf = (lines: number, string: number) => lines - string;

/** The y of `string`'s line in the tab staff drawing `bar`. */
export function tabLineY(layout: unknown, bar: alphaTab.model.Bar, string: number): { y: number; spacing: number } | null {
  const tab = tabStaff(layout, bar);
  return tab ? { y: tab.lineY(lineOf(tab.lines, string)), spacing: tab.spacing } : null;
}

function stringAt(layout: unknown, bar: alphaTab.model.Bar, y: number): number | null {
  const tab = tabStaff(layout, bar);
  if (!tab) return null;
  const { lineY, lines, spacing } = tab;
  if (y < lineY(0) - spacing / 2 || y > lineY(lines - 1) + spacing / 2) return null;
  const line = Math.min(lines - 1, Math.max(0, Math.round((y - lineY(0)) / spacing)));
  return lineOf(lines, line);
}
