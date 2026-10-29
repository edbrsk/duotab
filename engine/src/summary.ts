import * as alphaTab from '@coderline/alphatab';

import type { SongSummary } from './protocol';
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
      };
    }),
  };
}

export function summarize(bytes: Uint8Array, fileName: string): SongSummary {
  const score = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, new alphaTab.Settings());
  return summarizeScore(score, fileName);
}
