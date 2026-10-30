import * as alphaTab from '@coderline/alphatab';

import type { DirectionId, EditPosition, Structure } from '../protocol';
import { finishEdit } from './finish';

const { Direction } = alphaTab.model;
type Score = alphaTab.model.Score;

const defaultSettings = new alphaTab.Settings();
const MAX_REPEATS = 8;
const MAX_ENDINGS = 8;

// In the order the palette and `structureAt` list them.
const DIRECTIONS: Record<DirectionId, alphaTab.model.Direction> = {
  segno: Direction.TargetSegno,
  coda: Direction.TargetCoda,
  fine: Direction.TargetFine,
  daCapo: Direction.JumpDaCapo,
  daCapoAlFine: Direction.JumpDaCapoAlFine,
  daCapoAlCoda: Direction.JumpDaCapoAlCoda,
  dalSegno: Direction.JumpDalSegno,
  dalSegnoAlFine: Direction.JumpDalSegnoAlFine,
  dalSegnoAlCoda: Direction.JumpDalSegnoAlCoda,
  toCoda: Direction.JumpDaCoda,
};
const IDS = Object.keys(DIRECTIONS) as DirectionId[];
const JUMPS = new Set<DirectionId>(['daCapo', 'daCapoAlFine', 'daCapoAlCoda', 'dalSegno', 'dalSegnoAlFine', 'dalSegnoAlCoda', 'toCoda']);

function finishStructure(score: Score, at: EditPosition, settings: alphaTab.Settings): EditPosition {
  score.rebuildRepeatGroups();
  finishEdit(score, at, settings);
  return at;
}

export function toggleRepeatStart(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  const masterBar = score.masterBars[at.bar];
  masterBar.isRepeatStart = !masterBar.isRepeatStart;
  return finishStructure(score, at, settings);
}

/** `count` plays of the repeat; 0 removes the repeat end. */
export function setRepeatEnd(score: Score, at: EditPosition, count: number, settings = defaultSettings): EditPosition {
  if (!Number.isInteger(count) || (count !== 0 && (count < 2 || count > MAX_REPEATS))) {
    throw new Error(`repeat count ${count} out of range`);
  }
  score.masterBars[at.bar].repeatCount = count;
  return finishStructure(score, at, settings);
}

export function setEndings(score: Score, at: EditPosition, endings: number[], settings = defaultSettings): EditPosition {
  const invalid = endings.find((e) => !Number.isInteger(e) || e < 1 || e > MAX_ENDINGS);
  if (invalid !== undefined) throw new Error(`ending ${invalid} out of range`);
  // Ending n is bit n − 1.
  score.masterBars[at.bar].alternateEndings = endings.reduce((mask, e) => mask | (1 << (e - 1)), 0);
  return finishStructure(score, at, settings);
}

/** A bar holds one jump: choosing one replaces the bar's other. */
export function toggleDirection(score: Score, at: EditPosition, id: DirectionId, settings = defaultSettings): EditPosition {
  const masterBar = score.masterBars[at.bar];
  const direction = DIRECTIONS[id];
  if (masterBar.directions?.has(direction)) {
    masterBar.directions.delete(direction);
  } else {
    if (JUMPS.has(id)) for (const jump of JUMPS) masterBar.directions?.delete(DIRECTIONS[jump]);
    masterBar.addDirection(direction);
  }
  return finishStructure(score, at, settings);
}

export function structureAt(score: Score, at: EditPosition): Structure {
  const masterBar = score.masterBars[at.bar];
  return {
    repeatStart: masterBar.isRepeatStart,
    repeatCount: masterBar.repeatCount,
    endings: Array.from({ length: MAX_ENDINGS }, (_, i) => i + 1).filter((e) => masterBar.alternateEndings & (1 << (e - 1))),
    directions: IDS.filter((id) => masterBar.directions?.has(DIRECTIONS[id])),
  };
}

/** Master-bar indexes in the order playback goes through them. */
export function playOrder(score: Score, settings = defaultSettings): number[] {
  const generator = new alphaTab.midi.MidiFileGenerator(
    score,
    settings,
    new alphaTab.midi.AlphaSynthMidiFileHandler(new alphaTab.midi.MidiFile()),
  );
  generator.generate();
  return generator.tickLookup.masterBars.map((m) => m.masterBar.index);
}
