import * as alphaTab from '@coderline/alphatab';

import type { EditCommand, EditPosition } from '../protocol';
import { History } from './history';
import { deleteNote, move, selectVoice, setDuration, setFret, setRest } from './operations';
import { clampPosition, staffOf } from './position';

type Score = alphaTab.model.Score;

/** Bar, voice and beat counts: what a cursor move can add to. */
const shape = (score: Score, at: EditPosition) =>
  staffOf(score, at)
    .bars.map((bar) => bar.voices.map((voice) => voice.beats.length).join(','))
    .join('|');

/**
 * One edit command on the song. A step goes into `history` only when the song
 * changed, and a command that fails leaves no step.
 */
export function runCommand(
  score: Score,
  at: EditPosition,
  command: EditCommand,
  history: History,
  settings = new alphaTab.Settings(),
): { position: EditPosition; edited: boolean } {
  if (command.op === 'place') return { position: clampPosition(score, command.position), edited: false };

  // Up and down only move the cursor; skip the snapshot (about 30 ms on a long song).
  if (command.op === 'move' && (command.direction === 'up' || command.direction === 'down')) {
    return { position: move(score, at, command.direction, settings), edited: false };
  }
  const before = History.snapshot(score);
  const shapeBefore = shape(score, at);
  const position = (() => {
    switch (command.op) {
      case 'setFret':
        return setFret(score, at, command.fret, settings);
      case 'deleteNote':
        return deleteNote(score, at, settings);
      case 'setDuration':
        return setDuration(score, at, command.duration, command.dots, settings);
      case 'setRest':
        return setRest(score, at, settings);
      case 'selectVoice':
        return selectVoice(score, at, command.voice, settings);
      case 'move':
        return move(score, at, command.direction, settings);
    }
  })();
  const structural = command.op === 'move' || command.op === 'selectVoice';
  const edited = !structural || shape(score, at) !== shapeBefore;
  if (edited) history.push(before);
  return { position, edited };
}
