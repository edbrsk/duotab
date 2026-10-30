import type * as alphaTab from '@coderline/alphatab';

/**
 * alphaTab sets bar indexes, links, start ticks and repeat groups only as
 * bars are appended; after bars are inserted, removed or change length they
 * are set again here, before `score.finish`.
 */
export function relink(score: alphaTab.model.Score): void {
  let previous: alphaTab.model.MasterBar | null = null;
  for (const [index, masterBar] of score.masterBars.entries()) {
    masterBar.score = score;
    masterBar.index = index;
    masterBar.previousMasterBar = previous;
    masterBar.nextMasterBar = null;
    masterBar.start = 0;
    if (previous) {
      previous.nextMasterBar = masterBar;
      masterBar.start = previous.start + (previous.isAnacrusis ? 0 : previous.calculateDuration());
    }
    previous = masterBar;
  }
  score.rebuildRepeatGroups();
  for (const track of score.tracks) {
    for (const staff of track.staves) {
      for (const [index, bar] of staff.bars.entries()) {
        bar.staff = staff;
        bar.index = index;
        bar.previousBar = staff.bars[index - 1] ?? null;
        bar.nextBar = staff.bars[index + 1] ?? null;
      }
    }
  }
}
