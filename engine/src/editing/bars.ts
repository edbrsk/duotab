import * as alphaTab from '@coderline/alphatab';

import type { BarProperties, Clef, EditPosition } from '../protocol';
import { finishEdit } from './finish';
import { idSource } from './ids';
import { restsFilling, restTicks } from './operations';
import { barOf, staffOf } from './position';
import { relink } from './relink';

const { Automation, KeySignatureType, Ottavia } = alphaTab.model;
type Score = alphaTab.model.Score;
type MasterBar = alphaTab.model.MasterBar;

const defaultSettings = new alphaTab.Settings();
const DENOMINATORS = [1, 2, 4, 8, 16, 32];
const MIN_TEMPO = 30;
const MAX_TEMPO = 300;

// A guitar's treble clef is a plain G2: the staff's display transposition
// puts its notation an octave above the sound, as in Guitar Pro files.
const CLEFS: Record<Clef, [alphaTab.model.Clef, alphaTab.model.Ottavia]> = {
  treble: [alphaTab.model.Clef.G2, Ottavia.Regular],
  bass: [alphaTab.model.Clef.F4, Ottavia.Regular],
};

/** Indexes from `from` on while `same` holds, as a change runs until the next one. */
function runFrom(count: number, from: number, same: (index: number) => boolean): number[] {
  const indexes: number[] = [];
  for (let i = from; i < count && same(i); i++) indexes.push(i);
  return indexes;
}

export function setTimeSignature(
  score: Score,
  at: EditPosition,
  numerator: number,
  denominator: number,
  settings = defaultSettings,
): EditPosition {
  if (!Number.isInteger(numerator) || numerator < 1 || numerator > 32 || !DENOMINATORS.includes(denominator)) {
    throw new Error(`time signature ${numerator}/${denominator} out of range`);
  }
  const first = score.masterBars[at.bar];
  const old = [first.timeSignatureNumerator, first.timeSignatureDenominator];
  // The same numbers keep how the bar shows them, such as "C" for 4/4.
  if (old[0] === numerator && old[1] === denominator) return at;
  const changed = runFrom(score.masterBars.length, at.bar, (i) => {
    const m = score.masterBars[i];
    return m.timeSignatureNumerator === old[0] && m.timeSignatureDenominator === old[1];
  });
  const ids = idSource(score);
  for (const index of changed) {
    const masterBar = score.masterBars[index];
    masterBar.timeSignatureNumerator = numerator;
    masterBar.timeSignatureDenominator = denominator;
    masterBar.timeSignatureCommon = false;
    for (const track of score.tracks) {
      for (const staff of track.staves) refillIfRests(staff.bars[index], masterBar, ids);
    }
  }
  relink(score);
  finishEdit(score, at, settings);
  return at;
}

function refillIfRests(bar: alphaTab.model.Bar, masterBar: MasterBar, ids: ReturnType<typeof idSource>): void {
  if (!bar.voices.every((v) => v.beats.every((b) => b.isRest))) return;
  for (const [index, voice] of bar.voices.entries()) {
    const words = voice.beats
      .filter((b) => b.text || b.lyrics?.length)
      .map((b) => ({ tick: b.playbackStart, text: b.text, lyrics: b.lyrics }));
    voice.beats.length = 0;
    if (index === 0) {
      const rests = restsFilling(masterBar.calculateDuration(), ids);
      for (const rest of rests) voice.addBeat(rest);
      keepWords(rests, words);
    } else {
      const empty = new alphaTab.model.Beat();
      empty.id = ids.beat();
      empty.isEmpty = true;
      voice.addBeat(empty);
    }
  }
}

/** Each removed rest's text and lyrics go to the new rest that starts at or before it. */
function keepWords(
  rests: alphaTab.model.Beat[],
  words: { tick: number; text: string | null; lyrics: string[] | null }[],
): void {
  const starts: number[] = [];
  let tick = 0;
  for (const rest of rests) {
    starts.push(tick);
    tick += restTicks(rest);
  }
  for (const word of words) {
    let i = 0;
    while (i + 1 < starts.length && starts[i + 1] <= word.tick) i++;
    const rest = rests[i];
    if (word.text) rest.text = rest.text ? `${rest.text} ${word.text}` : word.text;
    if (word.lyrics?.length) rest.lyrics = [...(rest.lyrics ?? []), ...word.lyrics];
  }
}

const markingOf = (masterBar: MasterBar) => masterBar.tempoAutomations.find((a) => a.ratioPosition === 0);

function tempoAt(score: Score, index: number): number {
  const own = markingOf(score.masterBars[index]);
  if (own) return own.value;
  for (let i = index - 1; i >= 0; i--) {
    const automations = score.masterBars[i].tempoAutomations;
    if (automations.length > 0) return automations.reduce((a, b) => (b.ratioPosition >= a.ratioPosition ? b : a)).value;
  }
  return score.tempo;
}

/** Null removes the bar's tempo marking; the first bar always keeps one. */
export function setTempo(score: Score, at: EditPosition, bpm: number | null, settings = defaultSettings): EditPosition {
  if (bpm !== null && (!Number.isInteger(bpm) || bpm < MIN_TEMPO || bpm > MAX_TEMPO)) {
    throw new Error(`tempo ${bpm} out of range`);
  }
  if (bpm === null && at.bar === 0) return at;
  const masterBar = score.masterBars[at.bar];
  masterBar.tempoAutomations = masterBar.tempoAutomations.filter((a) => a.ratioPosition !== 0);
  if (bpm !== null) {
    masterBar.tempoAutomations.unshift(Automation.buildTempoAutomation(false, 0, bpm, 2));
    if (at.bar === 0) score.tempo = bpm;
  }
  finishEdit(score, at, settings);
  return at;
}

/** On every track, as the `.gp` writer reads the key from the first. */
export function setKeySignature(
  score: Score,
  at: EditPosition,
  key: number,
  minor: boolean,
  settings = defaultSettings,
): EditPosition {
  if (!Number.isInteger(key) || key < -7 || key > 7) throw new Error(`key signature ${key} out of range`);
  const bars = staffOf(score, at).bars;
  const old = bars[at.bar];
  const changed = runFrom(
    bars.length,
    at.bar,
    (i) => bars[i].keySignature === old.keySignature && bars[i].keySignatureType === old.keySignatureType,
  );
  const type = minor ? KeySignatureType.Minor : KeySignatureType.Major;
  for (const track of score.tracks) {
    for (const staff of track.staves) {
      for (const index of changed) {
        staff.bars[index].keySignature = key as alphaTab.model.KeySignature;
        staff.bars[index].keySignatureType = type;
      }
    }
  }
  finishEdit(score, at, settings);
  return at;
}

export function setClef(score: Score, at: EditPosition, clef: Clef, settings = defaultSettings): EditPosition {
  const bars = staffOf(score, at).bars;
  const old = bars[at.bar];
  const changed = runFrom(
    bars.length,
    at.bar,
    (i) => bars[i].clef === old.clef && bars[i].clefOttava === old.clefOttava,
  );
  const [value, ottava] = CLEFS[clef];
  for (const index of changed) {
    bars[index].clef = value;
    bars[index].clefOttava = ottava;
  }
  finishEdit(score, at, settings);
  return at;
}

export function barProperties(score: Score, at: EditPosition): BarProperties {
  const masterBar = score.masterBars[at.bar];
  const bar = barOf(score, at);
  const clef = (Object.keys(CLEFS) as Clef[]).find(
    (c) => CLEFS[c][0] === bar.clef && CLEFS[c][1] === bar.clefOttava,
  );
  return {
    numerator: masterBar.timeSignatureNumerator,
    denominator: masterBar.timeSignatureDenominator,
    key: bar.keySignature,
    minor: bar.keySignatureType === KeySignatureType.Minor,
    clef: clef ?? null,
    tempo: tempoAt(score, at.bar),
    tempoChange: at.bar === 0 || markingOf(masterBar) !== undefined,
  };
}
