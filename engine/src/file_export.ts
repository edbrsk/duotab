import * as alphaTab from '@coderline/alphatab';

import { fingerUnstrung } from './editing/fingering';
import { isGuitar } from './editing/tracks';
import type { StaffView } from './protocol';
import { printPages } from './print_pages';
import { setStaves, showNotationAndTab } from './staves';

/** A song file as the editor would open it: fingered, notation over tab. */
function load(bytes: Uint8Array): alphaTab.model.Score {
  const settings = new alphaTab.Settings();
  const score = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, settings);
  fingerUnstrung(score, settings);
  showNotationAndTab(score);
  return score;
}

/** A song file, not the open one, as `.gp`. */
export function fileGp(bytes: Uint8Array): Uint8Array {
  return new alphaTab.exporter.Gp7Exporter().export(load(bytes), new alphaTab.Settings());
}

/**
 * A song file's first guitar track on A4 pages, with the staves the owner
 * chose for it in `staves`, as Export prints the drawn track.
 */
export function filePdf(bytes: Uint8Array, staves: StaffView[], staveProfile: alphaTab.StaveProfile, fontUrl: string): string[] {
  const score = load(bytes);
  const track = score.tracks.findIndex((t) => !t.staves[0].isPercussion && isGuitar(t));
  if (track < 0) throw new Error('no guitar track');
  setStaves(score, staves.filter((view) => view.index === track));
  return printPages(score, track, staveProfile, fontUrl);
}
