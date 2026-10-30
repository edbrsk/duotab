import * as alphaTab from '@coderline/alphatab';

import type { EditCommand, EditPosition } from '../protocol';
import { History } from './history';
import { deleteNote, move, selectVoice, setDuration, setFret, setRest } from './operations';
import { clampPosition, staffOf } from './position';
import { activeTechniques, addGrace, bendAt, setBend, setDynamic, setTuplet, toggleTechnique } from './techniques';

type Score = alphaTab.model.Score;

/** Comparing it before and after a command tells a real change from a no-op. */
const shape = (score: Score, at: EditPosition) => {
  const staff = staffOf(score, at);
  return `${score.title}|${staff.bars
    .map((bar) =>
      bar.voices
        .map((voice) =>
          voice.beats
            .map((b) => {
              const value = `${b.duration}.${b.dots}${b.isEmpty ? 'e' : ''}g${b.graceType}t${b.tupletNumerator}:${b.tupletDenominator}d${b.dynamics}`;
              const position = { ...at, bar: bar.index, voice: voice.index, beat: b.index };
              const notes = b.notes.map((n) => {
                const note = { ...position, string: n.string };
                return `${n.string}/${n.fret}${activeTechniques(score, note)}${JSON.stringify(bendAt(score, note))}`;
              });
              // String 0 has no note, so it lists only the beat techniques.
              return `${value}${activeTechniques(score, { ...position, string: 0 })}:${notes.sort()}`;
            })
            .join(' '),
        )
        .join(','),
    )
    .join('|')}`;
};

/**
 * One edit command on the song. A step goes into `history` only when the song
 * changed, so a no-op never makes a "(DuoTab)" copy, and a command that fails
 * leaves no step.
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
      case 'toggle':
        return toggleTechnique(score, at, command.technique, settings);
      case 'setDynamic':
        return setDynamic(score, at, command.dynamic, settings);
      case 'setTuplet':
        return setTuplet(score, at, command.tuplet, settings);
      case 'addGrace':
        return addGrace(score, at, settings);
      case 'setBend':
        return setBend(score, at, command.bend, settings);
      case 'setTitle':
        score.title = command.title.trim();
        return at;
    }
  })();
  const edited = shape(score, at) !== shapeBefore;
  if (edited) history.push(before);
  return { position, edited };
}
