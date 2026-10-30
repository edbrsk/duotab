import type * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { OpenState } from '../src/open_state';

const song = {} as alphaTab.model.Score;

test('a failed open resets the file flag', async () => {
  const opens = new OpenState();
  const failed = opens.wait({ fromFile: true });
  opens.failed(new Error('bad file'));
  await expect(failed).rejects.toThrow('bad file');
  const next = opens.wait({ fromFile: false });
  expect(opens.loaded(song)).toBe(false);
  await expect(next).resolves.toBe(song);
});

test('a second open rejects the first one still waiting', async () => {
  const opens = new OpenState();
  const first = opens.wait({ fromFile: true });
  const second = opens.wait({ fromFile: true });
  await expect(first).rejects.toThrow('another song opened');
  expect(opens.loaded(song)).toBe(true);
  await expect(second).resolves.toBe(song);
});

test('a score that loads with no open waiting is not from a file', () => {
  expect(new OpenState().loaded(song)).toBe(false);
});

test('an open says whether it is from a file before its score loads', () => {
  const opens = new OpenState();
  expect(opens.waitingFromFile).toBe(false);
  void opens.wait({ fromFile: true }).catch(() => {});
  expect(opens.waitingFromFile).toBe(true);
  opens.failed(new Error('stop'));
  expect(opens.waitingFromFile).toBe(false);
});
