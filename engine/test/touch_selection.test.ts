import { afterEach, beforeEach, expect, test, vi } from 'vitest';

import { LongPressSelection, type TouchLike } from '../src/touch_selection';

type FakeBeat = { name: string; absolutePlaybackStart: number };
const beats: FakeBeat[] = ['b0', 'b1', 'b2'].map((name, i) => ({ name, absolutePlaybackStart: i * 960 }));
const beatAt = (x: number) => beats[Math.floor(x / 100)] ?? null;

let selected: [string, string][];
let committed: [string, string][];
let prevented = 0;
let selection: LongPressSelection<FakeBeat>;

const touch = (x: number, fingers = 1): TouchLike => ({
  touches: Array.from({ length: fingers }, () => ({ clientX: x, clientY: 10 })),
  preventDefault: () => prevented++,
});
const end = (): TouchLike => ({ touches: [], preventDefault: () => prevented++ });

beforeEach(() => {
  vi.useFakeTimers();
  selected = [];
  committed = [];
  prevented = 0;
  selection = new LongPressSelection<FakeBeat>({
    beatAt: (x) => beatAt(x),
    select: (start, finish) => selected.push([start.name, finish.name]),
    commit: (start, finish) => committed.push([start.name, finish.name]),
  });
});

afterEach(() => vi.useRealTimers());

test('a long press then a drag selects from the pressed beat', () => {
  selection.touchStart(touch(50));
  vi.advanceTimersByTime(400);
  selection.touchMove(touch(250));
  selection.touchEnd(end());
  expect(selected.at(-1)).toEqual(['b0', 'b2']);
  expect(prevented).toBe(2);
});

test('a swipe before the delay selects nothing', () => {
  selection.touchStart(touch(50));
  vi.advanceTimersByTime(100);
  selection.touchMove(touch(80));
  vi.advanceTimersByTime(1000);
  selection.touchEnd(end());
  expect(selected).toEqual([]);
  expect(prevented).toBe(0);
});

test('a long press without moving selects one beat', () => {
  selection.touchStart(touch(150));
  vi.advanceTimersByTime(400);
  selection.touchEnd(end());
  expect(selected.at(-1)).toEqual(['b1', 'b1']);
});

test('dragging backwards keeps the earlier beat first', () => {
  selection.touchStart(touch(250));
  vi.advanceTimersByTime(400);
  selection.touchMove(touch(50));
  expect(selected.at(-1)).toEqual(['b0', 'b2']);
});

test('a second finger cancels', () => {
  selection.touchStart(touch(50, 2));
  vi.advanceTimersByTime(400);
  selection.touchEnd(end());
  expect(selected).toEqual([]);
});

test('the selection is committed once, when the finger lifts', () => {
  selection.touchStart(touch(50));
  vi.advanceTimersByTime(400);
  selection.touchMove(touch(150));
  selection.touchMove(touch(250));
  expect(committed).toEqual([]);
  selection.touchEnd(end());
  expect(committed).toEqual([['b0', 'b2']]);
});
