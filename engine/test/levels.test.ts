import { expect, test } from 'vitest';

import { heardAt, LevelMeter } from '../src/levels';
import type { LevelFrame } from '../src/worker/synth_hooks';

const frame = (time: number, channels: LevelFrame['channels'], master: [number, number] = [0, 0]): LevelFrame => ({
  cmd: 'duoscore.levels',
  time,
  channels,
  master,
});
const track = { primaryChannel: 0, secondaryChannel: 1 };
const gain = 2;

test('releases frames when playback reaches them', () => {
  const meter = new LevelMeter();
  meter.add(frame(100, [[0, 0.5, 0.5]]), 2);
  meter.add(frame(600, [[0, 0.05, 0.05]]), 2);
  expect(meter.release(50, [track], gain, 0)).toBeNull();
  expect(meter.release(300, [track], gain, 100)!.tracks[0]).toEqual([0, 0]);
  expect(meter.release(700, [track], gain, 200)!.tracks[0]).toEqual([-20, -20]);
});

test("a track's level is the louder of its two channels", () => {
  const meter = new LevelMeter();
  meter.add(frame(100, [[0, 0.1, 0.1], [1, 0.5, 0.25]]), 2);
  expect(meter.release(100, [track], gain, 0)!.tracks[0]).toEqual([0, -6]);
});

test('master shows the mix after the master fader its sound was played with', () => {
  const meter = new LevelMeter();
  meter.add(frame(100, [], [0.25, 0.25]), 2 * 10 ** (-6 / 20));
  meter.add(frame(200, [], [0.25, 0.25]), 2);
  const levels = meter.release(100, [track], gain, 0)!;
  expect(levels.master![0]).toBeCloseTo(-12, 0);
  expect(levels.tracks[0]).toBeNull();
  expect(meter.release(200, [track], gain, 100)!.master![0]).toBeCloseTo(-6, 0);
});

// alphaTab's player times run in real milliseconds at any speed.
test('a level is heard the output latency after it plays', () => {
  expect(heardAt(1000, 200)).toBe(800);
});

test('quiet is nothing', () => {
  const meter = new LevelMeter();
  meter.add(frame(100, [[0, 0.0001, 0.0001]], [0.0001, 0.0001]), 2);
  const levels = meter.release(100, [track], gain, 0)!;
  expect(levels.tracks[0]).toBeNull();
  expect(levels.master).toBeNull();
});

test('frames due while posts wait are kept for the next post', () => {
  const meter = new LevelMeter(40);
  meter.add(frame(100, [[0, 0.5, 0.5]]), 2);
  expect(meter.release(100, [track], gain, 0)!.tracks[0]).toEqual([0, 0]);
  meter.add(frame(130, [[0, 0.25, 0.25]]), 2);
  expect(meter.release(130, [track], gain, 10)).toBeNull();
  expect(meter.release(150, [track], gain, 45)!.tracks[0]).toEqual([-6, -6]);
});
