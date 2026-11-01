import * as alphaTab from '@coderline/alphatab';

import type { GpMixer } from './gp_mixer';
import { dbFromVolume, masterDbFromStored, panFromStored, trackDbFromStored } from './mix_values';
import type { SongSummary } from './protocol';
import { fingerUnstrung } from './editing/fingering';
import { barsWithNotes, barTimeline } from './timeline';
import { classifyTrack } from './track_kind';

export function summarizeScore(score: alphaTab.model.Score, fileName: string): SongSummary {
  return {
    title: score.title.trim() || fileName.replace(/\.[^.]+$/, ''),
    artist: score.artist.trim(),
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
        volumeDb: dbFromVolume(track.playbackInfo.volume),
        pan: (track.playbackInfo.balance - 8) / 8,
        channel: track.playbackInfo.primaryChannel,
        barsWithNotes: [],
      };
    }),
    bars: [],
    unplayableNotes: 0,
    masterDb: 0,
  };
}

/** `unplayable`: the notes fingering on open could not place. */
/** `mixer`: the file's exact levels, where it has them. */
export function describeOpened(
  score: alphaTab.model.Score,
  fileName: string,
  unplayable = 0,
  mixer: GpMixer | null = null,
): SongSummary {
  const summary = summarizeScore(score, fileName);
  return {
    ...summary,
    unplayableNotes: unplayable,
    tracks: summary.tracks.map((t) => {
      const strip = mixer?.tracks[t.index];
      const levels = strip ? { volumeDb: trackDbFromStored(strip.volume), pan: panFromStored(strip.pan) } : {};
      return { ...t, ...levels, barsWithNotes: barsWithNotes(score.tracks[t.index]) };
    }),
    bars: barTimeline(score),
    masterDb: mixer?.master != null ? masterDbFromStored(mixer.master) : summary.masterDb,
  };
}

export function summarize(bytes: Uint8Array, fileName: string): SongSummary {
  const settings = new alphaTab.Settings();
  const score = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, settings);
  fingerUnstrung(score, settings);
  return summarizeScore(score, fileName);
}
