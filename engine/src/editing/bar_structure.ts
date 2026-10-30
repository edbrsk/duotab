import * as alphaTab from '@coderline/alphatab';

import type { EditPosition } from '../protocol';
import { finishEdit } from './finish';
import { idSource } from './ids';
import { appendBar, emptyVoice, restsFilling } from './operations';
import { staffOf } from './position';
import { relink } from './relink';

const { Automation, JsonConverter } = alphaTab.model;
type Score = alphaTab.model.Score;
type MasterBar = alphaTab.model.MasterBar;

const defaultSettings = new alphaTab.Settings();

/** Copied bars of one track, as a song of their own, so pasting rebuilds every technique. */
export type Clipboard = { json: string; bars: number };

const markingOf = (masterBar: MasterBar) => masterBar.tempoAutomations.find((a) => a.ratioPosition === 0);

/** A bar of rests before the cursor bar, in every track; the cursor moves onto it. */
export function insertBar(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  const index = at.bar;
  const next = score.masterBars[index];
  const masterBar = new alphaTab.model.MasterBar();
  masterBar.timeSignatureNumerator = next.timeSignatureNumerator;
  masterBar.timeSignatureDenominator = next.timeSignatureDenominator;
  masterBar.timeSignatureCommon = next.timeSignatureCommon;
  masterBar.tripletFeel = next.tripletFeel;
  const previous = score.masterBars[index - 1];
  // Inside a multi-bar ending, the new bar belongs to it.
  if (previous && previous.alternateEndings !== 0 && previous.alternateEndings === next.alternateEndings) {
    masterBar.alternateEndings = next.alternateEndings;
  }
  if (index === 0) {
    masterBar.tempoAutomations = next.tempoAutomations.filter((a) => a.ratioPosition === 0);
    next.tempoAutomations = next.tempoAutomations.filter((a) => a.ratioPosition !== 0);
    // A pickup opens the song; after the new bar it is a short bar like any other.
    next.isAnacrusis = false;
  }
  score.masterBars.splice(index, 0, masterBar);
  const ids = idSource(score);
  for (const track of score.tracks) {
    for (const staff of track.staves) {
      const model = staff.bars[index];
      const bar = new alphaTab.model.Bar();
      bar.id = ids.bar();
      bar.clef = model.clef;
      bar.clefOttava = model.clefOttava;
      bar.keySignature = model.keySignature;
      bar.keySignatureType = model.keySignatureType;
      const voice = new alphaTab.model.Voice();
      voice.id = ids.voice();
      for (const rest of restsFilling(masterBar.calculateDuration(), ids)) voice.addBeat(rest);
      bar.addVoice(voice);
      while (bar.voices.length < model.voices.length) bar.addVoice(emptyVoice(ids));
      staff.bars.splice(index, 0, bar);
    }
  }
  relink(score);
  const cursor = { ...at, voice: 0, beat: 0 };
  finishEdit(score, cursor, settings);
  return cursor;
}

const isJump = (direction: alphaTab.model.Direction) => alphaTab.model.Direction[direction].startsWith('Jump');
// Playback stops after the bar with Fine, so Fine closes a passage, as a jump does.
const closes = (direction: alphaTab.model.Direction) => isJump(direction) || direction === alphaTab.model.Direction.TargetFine;

/**
 * Keeps the song's form when `removed` goes: what opens a passage moves to
 * the next bar, what closes one to the previous bar, never over a mark that
 * bar has. A repeat that both opens and closes on `removed` goes with it.
 */
function carryForm(removed: MasterBar, previous: MasterBar | undefined, next: MasterBar | undefined): void {
  const oneBarRepeat = removed.isRepeatStart && removed.isRepeatEnd;
  if (next && removed.isRepeatStart && !oneBarRepeat) next.isRepeatStart = true;
  if (previous && removed.isRepeatEnd && !oneBarRepeat && !previous.isRepeatEnd) {
    previous.repeatCount = removed.repeatCount;
  }
  if (next && removed.section && !next.section) next.section = removed.section;
  const directions = [...(removed.directions ?? [])];
  // A mark and a jump on one bar, such as a segno with To Coda, stay together.
  const together = directions.some(closes) && directions.some((d) => !closes(d));
  if (together) {
    const target = next ?? previous;
    const hasJump = [...(target?.directions ?? [])].some(isJump);
    for (const direction of directions) if (!(isJump(direction) && hasJump)) target?.addDirection(direction);
    return;
  }
  for (const direction of directions) {
    if (!closes(direction)) {
      next?.addDirection(direction);
    } else if (previous && (!isJump(direction) || ![...(previous.directions ?? [])].some(isJump))) {
      previous.addDirection(direction);
    }
  }
}

/** Removes the cursor bar from every track; its tempo carries on in the next bar. */
export function deleteBar(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  if (score.masterBars.length === 1) return at;
  const index = at.bar;
  const removed = score.masterBars[index];
  // Its repeat end would move onto a bar that already ends one.
  if (removed.isRepeatEnd && !removed.isRepeatStart && score.masterBars[index - 1]?.isRepeatEnd) {
    throw new Error("this bar ends a repeat that can't move");
  }
  const next = score.masterBars[index + 1];
  const last = [...removed.tempoAutomations].sort((a, b) => a.ratioPosition - b.ratioPosition).at(-1);
  if (last && next && !markingOf(next)) {
    next.tempoAutomations.unshift(Automation.buildTempoAutomation(false, 0, last.value, 2));
  }
  carryForm(removed, score.masterBars[index - 1], next);
  score.masterBars.splice(index, 1);
  for (const track of score.tracks) {
    for (const staff of track.staves) staff.bars.splice(index, 1);
  }
  const first = markingOf(score.masterBars[0]);
  if (first) score.tempo = first.value;
  relink(score);
  const cursor = { ...at, bar: Math.min(index, score.masterBars.length - 1), voice: 0, beat: 0 };
  finishEdit(score, cursor, settings);
  return cursor;
}

/** The chord's id in `staff`, adding it there under a free id when the id means another chord. */
function chordIn(staff: alphaTab.model.Staff, chord: alphaTab.model.Chord | null, id: string): string | null {
  if (!chord) return null;
  const same = (other: alphaTab.model.Chord | undefined) =>
    other?.name === chord.name && other.strings.join() === chord.strings.join();
  let free = id;
  for (let n = 2; staff.chords?.has(free); n++) {
    if (same(staff.chords.get(free))) return free;
    free = `${id}-${n}`;
  }
  staff.addChord(free, chord);
  return free;
}

export function copyBars(score: Score, track: number, from: number, to: number): Clipboard {
  const song = JSON.parse(JsonConverter.scoreToJson(score));
  song.masterbars = song.masterbars.slice(from, to + 1);
  const copied = song.tracks[track];
  copied.staves = [{ ...copied.staves[0], bars: copied.staves[0].bars.slice(from, to + 1) }];
  song.tracks = [copied];
  // A link to a note outside the copied bars would fail to load; the flags
  // alone rebuild the links when pasted.
  for (const bar of copied.staves[0].bars) {
    for (const voice of bar.voices) {
      for (const beat of voice.beats) {
        for (const note of beat.notes) {
          for (const key of Object.keys(note)) if (key.endsWith('noteid')) delete note[key];
        }
      }
    }
  }
  return { json: JSON.stringify(song), bars: to - from + 1 };
}

/**
 * The copied bars' contents replace the cursor track's from the cursor bar
 * on; the bars keep their own time signature, tempo, key and clef.
 */
export function pasteBars(score: Score, at: EditPosition, clipboard: Clipboard, settings = defaultSettings): EditPosition {
  const sourceStaff = JsonConverter.jsonToScore(clipboard.json, settings).tracks[0].staves[0];
  const source = sourceStaff.bars;
  while (score.masterBars.length < at.bar + source.length) appendBar(score, settings);
  const staff = staffOf(score, at);
  const strings = staff.tuning.length;
  const ids = idSource(score);
  for (const [offset, copied] of source.entries()) {
    const target = staff.bars[at.bar + offset];
    target.voices = [];
    for (const voice of copied.voices) {
      voice.id = ids.voice();
      for (const beat of voice.beats) {
        beat.id = ids.beat();
        if (beat.chordId !== null) beat.chordId = chordIn(staff, sourceStaff.chords?.get(beat.chordId) ?? null, beat.chordId);
        for (const note of [...beat.notes]) {
          if (note.string > strings) beat.removeNote(note);
          else note.id = ids.note();
        }
      }
      target.addVoice(voice);
    }
  }
  const voices = Math.max(...staff.bars.map((b) => b.voices.length));
  for (const bar of staff.bars) while (bar.voices.length < voices) bar.addVoice(emptyVoice(ids));
  const cursor = { ...at, voice: 0, beat: 0 };
  finishEdit(score, cursor, settings);
  return cursor;
}
