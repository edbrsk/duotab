import * as alphaTab from '@coderline/alphatab';

import type { EditPosition } from '../protocol';
import { finishEdit } from './finish';
import { type IdSource, idSource } from './ids';
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
    // A tie would take the fret of the note it ties from.
    existing.isTieDestination = false;
    // alphaTab draws and plays a natural harmonic at its harmonic value.
    if (existing.harmonicType === alphaTab.model.HarmonicType.Natural) existing.harmonicValue = fret;
  } else {
    const note = new Note();
    note.id = idSource(score).note();
    note.string = at.string;
    note.fret = fret;
    beat.addNote(note);
  }
  beat.isEmpty = false;
  finishEdit(score, at, settings);
  return at;
}

/**
 * As in Guitar Pro: on a note, removes the note and leaves a rest; on a rest,
 * removes the beat so the bar shrinks. A bar's last beat is not removed: the
 * first voice is refilled with rests that fit the bar, and another voice
 * becomes unused again.
 */
export function deleteNote(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  const beat = beatOf(score, at);
  const note = beat.notes.find((n) => n.string === at.string);
  if (note) {
    beat.removeNote(note);
    // A grace note without notes has no rest to become.
    if (beat.graceType !== alphaTab.model.GraceType.None && beat.notes.length === 0) {
      removeBeat(score, at, beat);
    }
    finishEdit(score, at, settings);
    return at;
  }
  if (!beat.isRest || beat.isEmpty) return at;

  const voice = voiceOf(score, at);
  if (voice.beats.length > 1) {
    removeBeat(score, at, beat);
    finishEdit(score, at, settings);
    return { ...at, beat: Math.min(at.beat, voice.beats.length - 1) };
  }
  if (at.voice === 0) {
    const ticks = barOf(score, at).masterBar.calculateDuration();
    if (beat.playbackDuration === ticks) return at;
    voice.beats.length = 0;
    for (const rest of restsFilling(ticks, idSource(score))) voice.addBeat(rest);
  } else {
    beat.isEmpty = true;
  }
  finishEdit(score, at, settings);
  return { ...at, beat: 0 };
}

function removeBeat(score: Score, at: EditPosition, beat: alphaTab.model.Beat): void {
  voiceOf(score, at).beats.splice(at.beat, 1);
  // Voice.finish relinks beats, but not a last beat that now has none after it.
  if (beat.previousBeat) beat.previousBeat.nextBeat = beat.nextBeat;
  if (beat.nextBeat) beat.nextBeat.previousBeat = beat.previousBeat;
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
  beat.isEmpty = false;
  finishEdit(score, at, settings);
  return at;
}

export function setRest(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  const beat = beatOf(score, at);
  for (const note of [...beat.notes]) beat.removeNote(note);
  beat.isEmpty = false;
  finishEdit(score, at, settings);
  return at;
}

export function selectVoice(score: Score, at: EditPosition, voice: number, settings = defaultSettings): EditPosition {
  const target = { ...at, voice, beat: 0 };
  ensureVoice(score, target);
  finishEdit(score, at, settings);
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
      finishEdit(score, at, settings);
      return { ...previous, beat: voiceOf(score, previous).beats.length - 1 };
    }
    case 'right': {
      const voice = voiceOf(score, at);
      if (at.beat < voice.beats.length - 1) return { ...at, beat: at.beat + 1 };
      // An unused voice's empty beat is not drawn; leaving it would put a
      // hidden beat in front of the new one, which Guitar Pro shows as a rest.
      const current = beatOf(score, at);
      if (current.isEmpty) current.isEmpty = false;
      if (voiceTicks(voice) < barOf(score, at).masterBar.calculateDuration()) {
        const rest = new Beat();
        rest.id = idSource(score).beat();
        rest.duration = beatOf(score, at).duration;
        voice.addBeat(rest);
        finishEdit(score, at, settings);
        return { ...at, beat: at.beat + 1 };
      }
      if (at.bar === score.masterBars.length - 1) appendBar(score, settings);
      const next = { ...at, bar: at.bar + 1, beat: 0 };
      ensureVoice(score, next);
      finishEdit(score, at, settings);
      return next;
    }
  }
}

// Display time: a grace note takes its playback time from the beat before it, which can be in the bar before.
const voiceTicks = (voice: alphaTab.model.Voice) => voice.beats.reduce((t, b) => t + b.displayDuration, 0);

function emptyVoice(ids: IdSource): alphaTab.model.Voice {
  const voice = new Voice();
  voice.id = ids.voice();
  const empty = new Beat();
  empty.id = ids.beat();
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
  const ids = idSource(score);
  for (const bar of staffOf(score, at).bars) {
    while (bar.voices.length <= at.voice) bar.addVoice(emptyVoice(ids));
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

/** Rests that add up to `ticks`, longest first; `ids` when they join a song. */
export function restsFilling(ticks: number, ids?: IdSource): alphaTab.model.Beat[] {
  const rests: alphaTab.model.Beat[] = [];
  let left = ticks;
  for (const [duration, dots, value] of REST_VALUES) {
    while (left >= value) {
      const rest = new Beat();
      if (ids) rest.id = ids.beat();
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
  const ids = idSource(score);
  for (const track of score.tracks) {
    for (const staff of track.staves) {
      const last = staff.bars[staff.bars.length - 1];
      const bar = new alphaTab.model.Bar();
      bar.id = ids.bar();
      bar.clef = last.clef;
      bar.clefOttava = last.clefOttava;
      bar.keySignature = last.keySignature;
      bar.keySignatureType = last.keySignatureType;
      staff.addBar(bar);
      const voice = new Voice();
      voice.id = ids.voice();
      for (const rest of restsFilling(ticks, ids)) voice.addBeat(rest);
      bar.addVoice(voice);
      while (bar.voices.length < last.voices.length) bar.addVoice(emptyVoice(ids));
    }
  }
  score.finish(settings);
}
