import * as alphaTab from '@coderline/alphatab';

import { classifyTrack } from '../track_kind';
import { idSource } from './ids';
import { restsFilling } from './operations';

type Score = alphaTab.model.Score;
type Track = alphaTab.model.Track;

const defaultSettings = new alphaTab.Settings();
const DRUM_CHANNEL = 9;
const NEW_TRACK_VOLUME = 12;

export const isGuitar = (track: Track) =>
  classifyTrack({
    isPercussion: track.staves[0].isPercussion,
    stringCount: track.staves[0].isPercussion ? 0 : track.staves[0].tuning.length,
    midiProgram: track.playbackInfo.program,
  }) === 'guitar';

function reindex(score: Score, settings: alphaTab.Settings): void {
  for (const [index, track] of score.tracks.entries()) track.index = index;
  score.finish(settings);
}

/** The new track's index: the last. */
export function addTrack(score: Score, options: { tuning: number[]; program: number }, settings = defaultSettings): number {
  const used = new Set(score.tracks.flatMap((t) => [t.playbackInfo.primaryChannel, t.playbackInfo.secondaryChannel]));
  const free = Array.from({ length: 16 }, (_, c) => c).filter((c) => c !== DRUM_CHANNEL && !used.has(c));
  if (free.length === 0) throw new Error('no free MIDI channel');
  const track = new alphaTab.model.Track();
  const taken = new Set(score.tracks.map((t) => t.name));
  let n = 1;
  while (taken.has(`Guitar ${n}`)) n++;
  track.name = `Guitar ${n}`;
  track.playbackInfo.program = options.program;
  track.playbackInfo.volume = NEW_TRACK_VOLUME;
  track.playbackInfo.primaryChannel = free[0];
  track.playbackInfo.secondaryChannel = free[1] ?? free[0];
  track.ensureStaveCount(1);
  const staff = track.staves[0];
  staff.stringTuning.tunings = [...options.tuning];
  staff.showStandardNotation = true;
  staff.showTablature = true;
  // Guitar notation sits an octave above the sound, as in Guitar Pro files.
  staff.displayTranspositionPitch = -12;
  const model = (score.tracks.find(isGuitar) ?? score.tracks[0]).staves[0];
  const ids = idSource(score);
  for (const masterBar of score.masterBars) {
    const from = model.bars[masterBar.index];
    const bar = new alphaTab.model.Bar();
    bar.id = ids.bar();
    bar.clef = from.clef;
    bar.clefOttava = from.clefOttava;
    bar.keySignature = from.keySignature;
    bar.keySignatureType = from.keySignatureType;
    const voice = new alphaTab.model.Voice();
    voice.id = ids.voice();
    for (const rest of restsFilling(masterBar.calculateDuration(), ids)) voice.addBeat(rest);
    bar.addVoice(voice);
    staff.addBar(bar);
  }
  score.addTrack(track);
  reindex(score, settings);
  return track.index;
}

export function removeTrack(score: Score, index: number, settings = defaultSettings): void {
  const track = score.tracks[index];
  if (!track || !isGuitar(track)) throw new Error('only guitar tracks can be removed');
  if (score.tracks.filter(isGuitar).length === 1) throw new Error('the song keeps one guitar track');
  score.tracks.splice(index, 1);
  reindex(score, settings);
}

export function moveTrack(score: Score, from: number, to: number, settings = defaultSettings): void {
  const track = score.tracks[from];
  if (!track || to < 0 || to >= score.tracks.length) throw new Error(`no track ${from} to move to ${to}`);
  score.tracks.splice(from, 1);
  score.tracks.splice(to, 0, track);
  reindex(score, settings);
}

/** Sets the name only; a short name the file gave stays. */
export function renameTrack(score: Score, index: number, name: string, settings = defaultSettings): void {
  const trimmed = name.trim();
  if (!trimmed) throw new Error('a track needs a name');
  score.tracks[index].name = trimmed;
  score.finish(settings);
}

/** The guitar track at `index` or after it, else the one before it. */
export function nearestGuitar(score: Score, index: number): number {
  const after = score.tracks.findIndex((t, i) => i >= index && isGuitar(t));
  if (after >= 0) return after;
  for (let i = Math.min(index, score.tracks.length) - 1; i >= 0; i--) if (isGuitar(score.tracks[i])) return i;
  return 0;
}

