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
  if (index === 0) {
    masterBar.tempoAutomations = next.tempoAutomations.filter((a) => a.ratioPosition === 0);
    next.tempoAutomations = next.tempoAutomations.filter((a) => a.ratioPosition !== 0);
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

/** Removes the cursor bar from every track; its tempo carries on in the next bar. */
export function deleteBar(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  if (score.masterBars.length === 1) return at;
  const index = at.bar;
  const removed = score.masterBars[index];
  const next = score.masterBars[index + 1];
  const last = [...removed.tempoAutomations].sort((a, b) => a.ratioPosition - b.ratioPosition).at(-1);
  if (last && next && !markingOf(next)) {
    next.tempoAutomations.unshift(Automation.buildTempoAutomation(false, 0, last.value, 2));
  }
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

export function copyBars(score: Score, track: number, from: number, to: number): Clipboard {
  const song = JSON.parse(JsonConverter.scoreToJson(score));
  song.masterbars = song.masterbars.slice(from, to + 1);
  const copied = song.tracks[track];
  copied.staves = [{ ...copied.staves[0], bars: copied.staves[0].bars.slice(from, to + 1) }];
  song.tracks = [copied];
  return { json: JSON.stringify(song), bars: to - from + 1 };
}

/**
 * The copied bars' contents replace the cursor track's from the cursor bar
 * on; the bars keep their own time signature, tempo, key and clef.
 */
export function pasteBars(score: Score, at: EditPosition, clipboard: Clipboard, settings = defaultSettings): EditPosition {
  const source = JsonConverter.jsonToScore(clipboard.json, settings).tracks[0].staves[0].bars;
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
