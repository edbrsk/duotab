import { readFileSync } from 'node:fs';

import * as alphaTab from '@coderline/alphatab';
import { beforeAll, expect, test } from 'vitest';

import { installSynthHooks } from '../src/worker/synth_hooks';
import { score } from './fixtures';

const bank = new Uint8Array(readFileSync(new URL('../soundfont/GeneralUser-GS.sf2', import.meta.url)));
const hooks = installSynthHooks(alphaTab, () => {});

type Synth = {
  channelSetMute(channel: number, mute: boolean): void;
  processMidiMessage(e: alphaTab.midi.MidiEvent): void;
  _channels: { channelList: { panOffset: number }[] };
};

const song = score(String.raw`\title "Two"
.
\track "A" \tuning E4 B3 G3 D3 A2 E2
0.6.1 | 0.6.1
\track "B" \tuning E4 B3 G3 D3 A2 E2
r.1 | r.1`);
let a: number;
let b: number;

beforeAll(() => {
  a = song.tracks[0].playbackInfo.primaryChannel;
  b = song.tracks[1].playbackInfo.primaryChannel;
});

function exporter(before?: (synth: Synth) => void, of: alphaTab.model.Score = song) {
  const midi = new alphaTab.midi.MidiFile();
  new alphaTab.midi.MidiFileGenerator(of, new alphaTab.Settings(), new alphaTab.midi.AlphaSynthMidiFileHandler(midi)).generate();
  const options = new alphaTab.synth.AudioExportOptions();
  options.soundFonts = [bank];
  options.sampleRate = 44100;
  const ex = alphaTab.synth.AlphaSynth.prototype.exportAudio.call(
    { synthesizer: { presets: [] } } as never,
    options,
    midi,
    [],
    new Map(),
  ) as unknown as { _synth: Synth; render(ms: number): unknown };
  before?.(ex._synth);
  hooks.take();
  return ex;
}

test("measures each channel's level after its pan", () => {
  hooks.setPan(a, -2);
  const ex = exporter();
  ex.render(500);
  const levels = hooks.take();
  hooks.setPan(a, null);
  const channelA = levels.channels.find(([channel]) => channel === a)!;
  expect(channelA[1]).toBeGreaterThan(0.01);
  expect(channelA[2]).toBe(0);
  expect(levels.channels.some(([channel]) => channel === b)).toBe(false);
});

test("pan holds after the song's own pan message replays", () => {
  hooks.setPan(a, 0.5);
  const ex = exporter();
  ex._synth.processMidiMessage(new alphaTab.midi.ControlChangeEvent(0, 0, a, alphaTab.midi.ControllerType.PanCoarse, 64));
  expect(ex._synth._channels.channelList[a].panOffset).toBeCloseTo(0.25, 4);
  hooks.setPan(a, null);
});

test("the owner's pan shifts the song's own pan changes", () => {
  hooks.setPan(a, 0.5);
  const ex = exporter();
  const pan = (value: number) => {
    ex._synth.processMidiMessage(new alphaTab.midi.ControlChangeEvent(0, 0, a, alphaTab.midi.ControllerType.PanCoarse, value));
    return ex._synth._channels.channelList[a].panOffset;
  };
  expect(pan(0)).toBeCloseTo(-0.25, 6);
  expect(pan(127)).toBeCloseTo(0.5, 6);
  hooks.setPan(a, null);
});

test("a null pan gives the song's own back", () => {
  hooks.setPan(a, 0.5);
  const ex = exporter();
  hooks.setPan(a, null);
  ex._synth.processMidiMessage(new alphaTab.midi.ControlChangeEvent(0, 0, a, alphaTab.midi.ControllerType.PanCoarse, 0));
  expect(ex._synth._channels.channelList[a].panOffset).toBeCloseTo(-0.5, 6);
});

test('meters off measure nothing', () => {
  hooks.setMetering(false);
  exporter().render(500);
  const levels = hooks.take();
  hooks.setMetering(true);
  expect(levels.channels).toEqual([]);
  expect(levels.master).toEqual([0, 0]);
});

test('a muted channel measures nothing', () => {
  const ex = exporter((synth) => synth.channelSetMute(a, true));
  ex.render(500);
  const channelA = hooks.take().channels.find(([channel]) => channel === a);
  expect(channelA?.[1] ?? 0).toBe(0);
  expect(channelA?.[2] ?? 0).toBe(0);
});

test('the master is the mixed peak', () => {
  const ex = exporter();
  ex.render(500);
  const { channels, master } = hooks.take();
  const loudest = Math.max(...channels.flatMap(([, left, right]) => [left, right]));
  expect(Math.max(...master)).toBeGreaterThanOrEqual(loudest - 1e-6);
});

test("a chord's level is its strings together", () => {
  // The same A on two strings plays one sample twice, in phase.
  const peak = (tex: string) => {
    const s = score(String.raw`\title "A"
.
\track "A" \tuning E4 B3 G3 D3 A2 E2
${tex}`);
    exporter(undefined, s).render(300);
    const channel = s.tracks[0].playbackInfo.primaryChannel;
    return hooks.take().channels.find(([c]) => c === channel)![1];
  };
  expect(peak('(5.6 0.5).1')).toBeGreaterThan(1.5 * peak('5.6.1'));
});
