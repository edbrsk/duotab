import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { History } from '../../src/editing/history';
import { setFret } from '../../src/editing/operations';
import { fourQuarters, score } from '../fixtures';

const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 1 };
const fret = (s: ReturnType<typeof score>) => s.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0].fret;

test('undo restores the state before the edit and redo brings the edit back', async () => {
  const history = new History();
  const s = score(fourQuarters);
  history.record(s);
  setFret(s, at, 9);
  const undone = (await history.undo(s))!;
  expect(fret(undone)).toBe(0);
  expect(history.canRedo).toBe(true);
  expect(fret((await history.redo(undone))!)).toBe(9);
});

test('a new edit after undo drops the redo steps', async () => {
  const history = new History();
  const s = score(fourQuarters);
  history.record(s);
  setFret(s, at, 9);
  const undone = (await history.undo(s))!;
  history.record(undone);
  setFret(undone, at, 3);
  expect(history.canRedo).toBe(false);
});

test('keeps at most the limit', async () => {
  const history = new History(2);
  let s = score(fourQuarters);
  for (const f of [1, 2, 3]) {
    history.record(s);
    setFret(s, at, f);
  }
  s = (await history.undo(s))!;
  s = (await history.undo(s))!;
  expect(history.canUndo).toBe(false);
  expect(await history.undo(s)).toBeNull();
});

test('a restored score is independent of the history', async () => {
  const history = new History();
  const s = score(fourQuarters);
  history.record(s);
  setFret(s, at, 5);
  history.record(s);
  setFret(s, at, 7);
  const five = (await history.undo(s))!;
  setFret(five, at, 11);
  expect(fret((await history.undo(five))!)).toBe(0);
});

test('clear forgets everything', async () => {
  const history = new History();
  history.record(score(fourQuarters));
  history.clear();
  expect(history.canUndo).toBe(false);
});

test('keeps snapshots compressed', async () => {
  const history = new History();
  const s = score(fourQuarters);
  history.record(s);
  const json = alphaTab.model.JsonConverter.scoreToJson(s).length;
  expect(await history.storedBytes()).toBeLessThan(json / 4);
});
