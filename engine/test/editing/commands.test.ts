import { expect, test } from 'vitest';

import { runCommand } from '../../src/editing/commands';
import { History } from '../../src/editing/history';
import type { EditPosition } from '../../src/protocol';
import { fourQuarters, score } from '../fixtures';

const start: EditPosition = { track: 0, bar: 0, voice: 0, beat: 0, string: 1 };

test('an edit records history and reports the change', () => {
  const s = score(fourQuarters);
  const history = new History();
  const result = runCommand(s, start, { op: 'setFret', fret: 9 }, history);
  expect(result.edited).toBe(true);
  expect(history.canUndo).toBe(true);
  expect(s.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0].fret).toBe(9);
});

test('moving the cursor is not an edit', () => {
  const history = new History();
  const result = runCommand(score(fourQuarters), start, { op: 'move', direction: 'right' }, history);
  expect(result).toEqual({ position: { ...start, beat: 1 }, edited: false });
  expect(history.canUndo).toBe(false);
});

test('moving right into a new bar is an edit', () => {
  const s = score(fourQuarters);
  const history = new History();
  const result = runCommand(s, { ...start, bar: 1 }, { op: 'move', direction: 'right' }, history);
  expect(result.edited).toBe(true);
  expect(history.canUndo).toBe(true);
  expect(s.masterBars).toHaveLength(3);
});

test('place clamps the position to the song', () => {
  const result = runCommand(
    score(fourQuarters),
    start,
    { op: 'place', position: { track: 0, bar: 9, voice: 3, beat: 9, string: 9 } },
    new History(),
  );
  expect(result.position).toEqual({ track: 0, bar: 1, voice: 0, beat: 0, string: 6 });
});

test('a failed edit leaves no history step', () => {
  const history = new History();
  expect(() => runCommand(score(fourQuarters), start, { op: 'setFret', fret: 30 }, history)).toThrow();
  expect(history.canUndo).toBe(false);
});
