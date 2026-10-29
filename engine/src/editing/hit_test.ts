import type * as alphaTab from '@coderline/alphatab';

export type Hit = { track: number; bar: number; voice: number; beat: number; string: number | null };

// The parts of alphaTab 1.6.1's internal layout (ScoreLayout._systems →
// StaffSystem.staves → StaffTrackGroup.staves → RenderStaff.barRenderers) that
// locate tab lines; boundsLookup has no string positions.
type BarRenderer = { bar: alphaTab.model.Bar; y: number; drawnLineCount: number; getLineY(line: number): number };
type RenderStaff = { staffId: string; y: number; barRenderers: BarRenderer[] };
type StaffSystem = { y: number; staves: { staves: RenderStaff[] }[] };

type Renderer = { boundsLookup: alphaTab.rendering.BoundsLookup | null };

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
  const layout = (renderer as { layout?: unknown }).layout;
  return { track, bar: bar.index, voice, beat, string: stringAt(layout, bar, y) };
}

function stringAt(layout: unknown, bar: alphaTab.model.Bar, y: number): number | null {
  const systems = (layout as { _systems?: StaffSystem[] })._systems ?? [];
  for (const system of systems) {
    for (const group of system.staves) {
      for (const staff of group.staves) {
        if (staff.staffId !== 'tab') continue;
        const renderer = staff.barRenderers.find((r) => r.bar === bar);
        if (!renderer) continue;
        const lineY = (line: number) => system.y + staff.y + renderer.y + renderer.getLineY(line);
        const lines = renderer.drawnLineCount;
        const spacing = lineY(1) - lineY(0);
        if (y < lineY(0) - spacing / 2 || y > lineY(lines - 1) + spacing / 2) return null;
        const line = Math.min(lines - 1, Math.max(0, Math.round((y - lineY(0)) / spacing)));
        // The top line is the highest string, which alphaTab numbers last.
        return lines - line;
      }
    }
  }
  return null;
}
