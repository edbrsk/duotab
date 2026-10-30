import * as alphaTab from '@coderline/alphatab';

import type { SongSummary } from './protocol';
import { fingerUnstrung } from './editing/fingering';
import { barsWithNotes, barTimeline } from './timeline';
import { classifyTrack } from './track_kind';

export function summarizeScore(score: alphaTab.model.Score, fileName: string): SongSummary {
  return {
    title: score.title.trim() || fileName.replace(/\.[^.]+$/, ''),
    tracks: score.tracks.map((track, index) => {
      const staff = track.staves[0];
      // alphaTab gives percussion staves a default guitar tuning; it means nothing there.
      const strings = staff.isPercussion ? [] : staff.tuning;
      return {
        index,
        name: track.name,
        kind: classifyTrack({
          isPercussion: staff.isPercussion,
          stringCount: strings.length,
          midiProgram: track.playbackInfo.program,
        }),
        stringCount: strings.length > 0 ? strings.length : null,
        tuning: strings.length > 0 ? [...strings] : null,
        midiProgram: track.playbackInfo.program,
        volume: track.playbackInfo.volume,
        channel: track.playbackInfo.primaryChannel,
        barsWithNotes: [],
      };
    }),
    bars: [],
    unplayableNotes: 0,
  };
}

/** `unplayable`: the notes fingering on open could not place. */
export function describeOpened(score: alphaTab.model.Score, fileName: string, unplayable = 0): SongSummary {
  const summary = summarizeScore(score, fileName);
  return {
    ...summary,
    unplayableNotes: unplayable,
    tracks: summary.tracks.map((t) => ({ ...t, barsWithNotes: barsWithNotes(score.tracks[t.index]) })),
    bars: barTimeline(score),
  };
}

export function summarize(bytes: Uint8Array, fileName: string): SongSummary {
  const settings = new alphaTab.Settings();
  const score = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, settings);
  fingerUnstrung(score, settings);
  return summarizeScore(score, fileName);
}
