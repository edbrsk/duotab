import type * as alphaTab from '@coderline/alphatab';

import type { StaffView } from './protocol';

/**
 * Guitar Pro files save which staves a track shows, and alphaTab draws only
 * those; DuoTab draws notation above tab unless the owner hides one.
 */
export function showNotationAndTab(score: alphaTab.model.Score): void {
  for (const track of score.tracks) {
    const staff = track.staves[0];
    if (staff.isPercussion || staff.tuning.length === 0) continue;
    staff.showStandardNotation = true;
    staff.showTablature = true;
  }
}

export function setStaves(score: alphaTab.model.Score, views: StaffView[]): void {
  for (const view of views) {
    if (!view.notation && !view.tab) throw new Error('a track needs notation or tab');
    const staff = score.tracks[view.index]?.staves[0];
    if (!staff) throw new Error(`no track ${view.index}`);
    staff.showStandardNotation = view.notation;
    staff.showTablature = view.tab;
  }
}
