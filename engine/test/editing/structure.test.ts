import * as alphaTab from '@coderline/alphatab';
import { beforeEach, expect, test } from 'vitest';

import {
  playOrder,
  setEndings,
  setRepeatEnd,
  structureAt,
  toggleEnding,
  toggleDirection,
  toggleRepeatStart,
} from '../../src/editing/structure';
import type { EditPosition } from '../../src/protocol';
import { score, sixBars } from '../fixtures';

const at = (bar: number): EditPosition => ({ track: 0, bar, voice: 0, beat: 0, string: 1 });
let s: alphaTab.model.Score;

beforeEach(() => {
  s = score(sixBars);
});

const repeatWithEndings = () => {
  toggleRepeatStart(s, at(1));
  setRepeatEnd(s, at(2), 2);
  setEndings(s, at(2), [1]);
  setEndings(s, at(3), [2]);
};

test('a repeat plays its bars twice', () => {
  toggleRepeatStart(s, at(1));
  setRepeatEnd(s, at(2), 2);
  expect(playOrder(s)).toEqual([0, 1, 2, 1, 2, 3, 4, 5]);
  setRepeatEnd(s, at(2), 3);
  expect(playOrder(s)).toEqual([0, 1, 2, 1, 2, 1, 2, 3, 4, 5]);
});

test('alternate endings take their pass', () => {
  repeatWithEndings();
  expect(playOrder(s)).toEqual([0, 1, 2, 1, 3, 4, 5]);
  expect(structureAt(s, at(2))).toEqual({ repeatStart: false, repeatCount: 2, endings: [1], directions: [] });
  expect(structureAt(s, at(1))).toEqual({ repeatStart: true, repeatCount: 0, endings: [], directions: [] });
});

test('D.S. al Fine goes back to the segno and stops at Fine', () => {
  repeatWithEndings();
  toggleDirection(s, at(4), 'segno');
  toggleDirection(s, at(4), 'fine');
  toggleDirection(s, at(5), 'dalSegnoAlFine');
  expect(playOrder(s)).toEqual([0, 1, 2, 1, 3, 4, 5, 4]);
});

test('D.C. al Coda takes the coda', () => {
  toggleDirection(s, at(1), 'toCoda');
  toggleDirection(s, at(3), 'daCapoAlCoda');
  toggleDirection(s, at(4), 'coda');
  expect(playOrder(s)).toEqual([0, 1, 2, 3, 0, 1, 4, 5]);
});

test('a bar holds one jump', () => {
  toggleDirection(s, at(3), 'daCapo');
  toggleDirection(s, at(3), 'dalSegno');
  expect(structureAt(s, at(3)).directions).toEqual(['dalSegno']);
  toggleDirection(s, at(3), 'dalSegno');
  expect(structureAt(s, at(3)).directions).toEqual([]);
  toggleDirection(s, at(4), 'fine');
  toggleDirection(s, at(4), 'segno');
  expect(structureAt(s, at(4)).directions).toEqual(['segno', 'fine']);
});

test('toggles undo themselves', () => {
  const empty = structureAt(s, at(2));
  toggleRepeatStart(s, at(2));
  toggleRepeatStart(s, at(2));
  setRepeatEnd(s, at(2), 4);
  setRepeatEnd(s, at(2), 0);
  setEndings(s, at(2), [1, 3]);
  setEndings(s, at(2), []);
  expect(structureAt(s, at(2))).toEqual(empty);
  expect(playOrder(s)).toEqual([0, 1, 2, 3, 4, 5]);
});

test('incomplete structures still play through', () => {
  toggleDirection(s, at(3), 'dalSegno');
  expect(playOrder(s)).toEqual([0, 1, 2, 3, 4, 5]);
  s = score(sixBars);
  setRepeatEnd(s, at(2), 2);
  expect(playOrder(s)).toEqual([0, 1, 2, 0, 1, 2, 3, 4, 5]);
});

test('other directions are left alone', () => {
  s.masterBars[2].addDirection(alphaTab.model.Direction.TargetDoubleCoda);
  toggleDirection(s, at(2), 'segno');
  toggleDirection(s, at(2), 'segno');
  toggleDirection(s, at(2), 'daCapo');
  expect([...s.masterBars[2].directions!]).toContain(alphaTab.model.Direction.TargetDoubleCoda);
  expect(structureAt(s, at(2)).directions).toEqual(['daCapo']);
});

test('out-of-range values are refused', () => {
  expect(() => setRepeatEnd(s, at(2), 1)).toThrow('repeat count 1 out of range');
  expect(() => setRepeatEnd(s, at(2), 9)).toThrow('repeat count 9 out of range');
  expect(() => setEndings(s, at(2), [0])).toThrow('ending 0 out of range');
  expect(() => setEndings(s, at(2), [9])).toThrow('ending 9 out of range');
});

test('structure survives the .gp round-trip and plays the same', () => {
  repeatWithEndings();
  toggleDirection(s, at(4), 'segno');
  toggleDirection(s, at(4), 'fine');
  toggleDirection(s, at(5), 'dalSegnoAlFine');
  toggleDirection(s, at(0), 'coda');
  const settings = new alphaTab.Settings();
  const reloaded = alphaTab.importer.ScoreLoader.loadScoreFromBytes(
    new alphaTab.exporter.Gp7Exporter().export(s, settings),
    settings,
  );
  const read = (song: alphaTab.model.Score) => song.masterBars.map((_, i) => structureAt(song, at(i)));
  expect(read(reloaded)).toEqual(read(s));
  expect(playOrder(reloaded)).toEqual(playOrder(s));
});

test('toggleEnding adds and removes one ending', () => {
  toggleEnding(s, at(2), 2);
  toggleEnding(s, at(2), 1);
  expect(structureAt(s, at(2)).endings).toEqual([1, 2]);
  toggleEnding(s, at(2), 2);
  expect(structureAt(s, at(2)).endings).toEqual([1]);
  expect(() => toggleEnding(s, at(2), 9)).toThrow('ending 9 out of range');
});
