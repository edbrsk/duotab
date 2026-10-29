import * as alphaTab from '@coderline/alphatab';

import type { EditPosition } from '../protocol';
import { barOf, beatOf, type Direction, staffOf, voiceOf } from './position';

const { Beat, Duration, Note, Voice } = alphaTab.model;
type Score = alphaTab.model.Score;

const MAX_FRET = 24;
const defaultSettings = new alphaTab.Settings();

export function setFret(score: Score, at: EditPosition, fret: number, settings = defaultSettings): EditPosition {
  if (!Number.isInteger(fret) || fret < 0 || fret > MAX_FRET) throw new Error(`fret ${fret} out of range`);
  const beat = beatOf(score, at);
  const existing = beat.notes.find((n) => n.string === at.string);
  if (existing) {
    existing.fret = fret;
  } else {
    const note = new Note();
    note.string = at.string;
    note.fret = fret;
    beat.addNote(note);
  }
  beat.isEmpty = false;
  score.finish(settings);
  return at;
}

export function deleteNote(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  const beat = beatOf(score, at);
  const note = beat.notes.find((n) => n.string === at.string);
  if (note) beat.removeNote(note);
  score.finish(settings);
  return at;
}

export function setDuration(
  score: Score,
  at: EditPosition,
  duration: alphaTab.model.Duration,
  dots: number,
  settings = defaultSettings,
): EditPosition {
  const beat = beatOf(score, at);
  beat.duration = duration;
  beat.dots = dots;
  score.finish(settings);
  return at;
}

export function setRest(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  const beat = beatOf(score, at);
  for (const note of [...beat.notes]) beat.removeNote(note);
  beat.isEmpty = false;
  score.finish(settings);
  return at;
}

export function selectVoice(score: Score, at: EditPosition, voice: number, settings = defaultSettings): EditPosition {
  const target = { ...at, voice, beat: 0 };
  ensureVoice(score, target);
  score.finish(settings);
  return target;
}

export function move(score: Score, at: EditPosition, direction: Direction, settings = defaultSettings): EditPosition {
  const strings = staffOf(score, at).tuning.length;
  switch (direction) {
    case 'up':
      return { ...at, string: Math.min(at.string + 1, strings) };
    case 'down':
      return { ...at, string: Math.max(at.string - 1, 1) };
    case 'left': {
      if (at.beat > 0) return { ...at, beat: at.beat - 1 };
      if (at.bar === 0) return at;
      const previous = { ...at, bar: at.bar - 1 };
      ensureVoice(score, previous);
      score.finish(settings);
      return { ...previous, beat: voiceOf(score, previous).beats.length - 1 };
    }
    case 'right': {
      const voice = voiceOf(score, at);
      if (at.beat < voice.beats.length - 1) return { ...at, beat: at.beat + 1 };
      if (voiceTicks(voice) < barOf(score, at).masterBar.calculateDuration()) {
        const rest = new Beat();
        rest.duration = beatOf(score, at).duration;
        voice.addBeat(rest);
        score.finish(settings);
        return { ...at, beat: at.beat + 1 };
      }
      if (at.bar === score.masterBars.length - 1) appendBar(score, settings);
      const next = { ...at, bar: at.bar + 1, beat: 0 };
      ensureVoice(score, next);
      score.finish(settings);
      return next;
    }
  }
}

const voiceTicks = (voice: alphaTab.model.Voice) => voice.beats.reduce((t, b) => t + b.playbackDuration, 0);

function emptyVoice(): alphaTab.model.Voice {
  const voice = new Voice();
  const empty = new Beat();
  empty.isEmpty = true;
  voice.addBeat(empty);
  return voice;
}

/**
 * Voices up to `at.voice`, added to every bar of the staff: alphaTab chains
 * each voice into the same voice of the next bar. A new voice has one empty
 * beat, which is neither drawn nor checked.
 */
function ensureVoice(score: Score, at: EditPosition): void {
  for (const bar of staffOf(score, at).bars) {
    while (bar.voices.length <= at.voice) bar.addVoice(emptyVoice());
  }
}

const QUARTER = 960;
/** Rest values from longest to shortest, as [duration, dots, ticks]. */
const REST_VALUES: [alphaTab.model.Duration, number, number][] = [
  [Duration.Whole, 0, QUARTER * 4],
  [Duration.Half, 1, QUARTER * 3],
  [Duration.Half, 0, QUARTER * 2],
  [Duration.Quarter, 1, QUARTER * 1.5],
  [Duration.Quarter, 0, QUARTER],
  [Duration.Eighth, 1, QUARTER * 0.75],
  [Duration.Eighth, 0, QUARTER / 2],
  [Duration.Sixteenth, 0, QUARTER / 4],
  [Duration.ThirtySecond, 0, QUARTER / 8],
  [Duration.SixtyFourth, 0, QUARTER / 16],
];

/** Rests that add up to `ticks`, longest first. */
export function restsFilling(ticks: number): alphaTab.model.Beat[] {
  const rests: alphaTab.model.Beat[] = [];
  let left = ticks;
  for (const [duration, dots, value] of REST_VALUES) {
    while (left >= value) {
      const rest = new Beat();
      rest.duration = duration;
      rest.dots = dots;
      rests.push(rest);
      left -= value;
    }
  }
  return rests;
}

/** A bar at the end of the song, in the time signature in force, for every track. */
export function appendBar(score: Score, settings = defaultSettings): void {
  const previous = score.masterBars[score.masterBars.length - 1];
  const masterBar = new alphaTab.model.MasterBar();
  masterBar.timeSignatureNumerator = previous.timeSignatureNumerator;
  masterBar.timeSignatureDenominator = previous.timeSignatureDenominator;
  masterBar.timeSignatureCommon = previous.timeSignatureCommon;
  score.addMasterBar(masterBar);
  const ticks = masterBar.calculateDuration();
  for (const track of score.tracks) {
    for (const staff of track.staves) {
      const last = staff.bars[staff.bars.length - 1];
      const bar = new alphaTab.model.Bar();
      bar.clef = last.clef;
      bar.clefOttava = last.clefOttava;
      bar.keySignature = last.keySignature;
      bar.keySignatureType = last.keySignatureType;
      staff.addBar(bar);
      const voice = new Voice();
      for (const rest of restsFilling(ticks)) voice.addBeat(rest);
      bar.addVoice(voice);
      while (bar.voices.length < last.voices.length) bar.addVoice(emptyVoice());
    }
  }
  score.finish(settings);
}
