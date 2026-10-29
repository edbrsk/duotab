import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { checkBars, describeOff } from '../../src/editing/bar_check';
import { deleteNote, selectVoice, setDuration } from '../../src/editing/operations';
import { fourQuarters, score } from '../fixtures';

const at = (bar: number, beat: number) => ({ track: 0, bar, voice: 0, beat, string: 1 });

test('a full bar has no issue', () => {
  expect(checkBars(score(fourQuarters), 0)).toEqual([]);
});

test('a short bar reports how much is missing', () => {
  const s = score(fourQuarters);
  setDuration(s, at(0, 3), alphaTab.model.Duration.Eighth, 0);
  expect(checkBars(s, 0)).toEqual([{ bar: 0, voice: 0, ticksOff: -480 }]);
});

test('a long bar reports how much is extra', () => {
  const s = score(fourQuarters);
  setDuration(s, at(0, 0), alphaTab.model.Duration.Half, 0);
  expect(checkBars(s, 0)).toEqual([{ bar: 0, voice: 0, ticksOff: 960 }]);
});

test('an unused voice is not checked', () => {
  const s = score(fourQuarters);
  selectVoice(s, at(0, 0), 1);
  expect(checkBars(s, 0)).toEqual([]);
});

test('describeOff names the amount as a fraction of a whole note', () => {
  expect(describeOff(-480)).toBe('⅛ short');
  expect(describeOff(960)).toBe('¼ long');
  expect(describeOff(-720)).toBe('3/16 short');
  expect(describeOff(1920)).toBe('½ long');
  expect(describeOff(-160)).toBe('1/24 short');
});

test('deleting rests clears the bar check once the bar is refilled', () => {
  const s = score(fourQuarters);
  setDuration(s, at(1, 0), alphaTab.model.Duration.Eighth, 0);
  expect(checkBars(s, 0)).toEqual([{ bar: 1, voice: 0, ticksOff: -3360 }]);
  deleteNote(s, { ...at(1, 0), string: 1 });
  expect(checkBars(s, 0)).toEqual([]);
});
