import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { setDuration } from '../../src/editing/operations';
import { EditSession } from '../../src/editing/session';
import { fourQuarters, lineOfEighths, score, twoGuitarsAndDrums } from '../fixtures';

test("opening a song checks its bars and clears the cursor and history", async () => {
  const s = score(fourQuarters);
  setDuration(s, { track: 0, bar: 0, voice: 0, beat: 3, string: 1 }, alphaTab.model.Duration.Eighth, 0);
  const session = new EditSession();
  session.open(s, 0);
  expect(session.issues).toEqual([{ bar: 0, voice: 0, ticksOff: -480 }]);
  expect(session.position).toBeNull();
  expect(session.state(s, false).canUndo).toBe(false);
});

test('a track switch checks that track and clears the cursor', () => {
  const s = score(twoGuitarsAndDrums);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  session.drawTrack(s, 1);
  expect(session.position).toBeNull();
  expect(session.track).toBe(1);
});

test('commands need a placed cursor', () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  expect(() => session.command(s, { op: 'setFret', fret: 3 })).toThrow('no cursor');
});

test("the state tells the cursor beat's note value", () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 1, voice: 0, beat: 0, string: 1 } });
  expect(session.state(s, false).beat).toMatchObject({ duration: 1, dots: 0 });
});

test('an edit rechecks the bars', () => {
  const s = score(fourQuarters);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 3, string: 1 } });
  const { edited } = session.command(s, { op: 'setDuration', duration: 8, dots: 0 });
  expect(edited).toBe(true);
  expect(session.state(s, true).issues).toEqual([{ bar: 0, voice: 0, ticksOff: -480 }]);
});

test('the state lists the techniques at the cursor', () => {
  const s = score(lineOfEighths);
  const session = new EditSession();
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 4 } });
  session.command(s, { op: 'toggle', technique: 'palmMute' });
  expect(session.state(s, true).beat).toEqual({
    duration: 8,
    dots: 0,
    techniques: ['palmMute'],
    dynamic: 'f',
    tuplet: 1,
    hasNote: true,
    bend: null,
  });
  session.command(s, { op: 'setBend', bend: { kind: 'bendRelease', amount: 6 } });
  expect(session.state(s, true).beat?.bend).toEqual({ kind: 'bendRelease', amount: 6 });
  session.command(s, { op: 'move', direction: 'up' });
  expect(session.state(s, false).beat).toMatchObject({ techniques: [], hasNote: false });
});
