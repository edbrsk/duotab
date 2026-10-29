import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { Mixer, type MixerApi, type MixerTrack } from '../src/mixer';

function fakeApi(programs: number[]) {
  const calls: string[] = [];
  const handlers: (() => void)[] = [];
  const tracks: MixerTrack[] = programs.map((program, i) => ({
    playbackInfo: { program, primaryChannel: i * 2, secondaryChannel: i * 2 + 1 },
  }));
  let range: { startTick: number; endTick: number } | null = null;
  const api = {
    score: { tracks },
    tickPosition: 0,
    playerState: alphaTab.synth.PlayerState.Paused as alphaTab.synth.PlayerState,
    isLooping: false as boolean,
    // alphaTab's player seeks to the start of a range it is given.
    get playbackRange() {
      return range;
    },
    set playbackRange(value: { startTick: number; endTick: number } | null) {
      range = value;
      if (value) this.tickPosition = value.startTick;
    },
    player: {
      setChannelMute: (channel: number, mute: boolean) => calls.push(`channel mute ${channel} ${mute}`),
      setChannelSolo: (channel: number, solo: boolean) => calls.push(`channel solo ${channel} ${solo}`),
    },
    play() {
      calls.push('play');
      this.playerState = alphaTab.synth.PlayerState.Playing;
    },
    pause() {
      calls.push('pause');
      this.playerState = alphaTab.synth.PlayerState.Paused;
    },
    loadMidiForScore() {
      calls.push('loadMidi');
      // alphaTab drops the position and reports the new MIDI asynchronously.
      this.tickPosition = 0;
      queueMicrotask(() => handlers.splice(0).forEach((h) => h()));
    },
    changeTrackMute(ts: MixerTrack[], mute: boolean) {
      calls.push(`mute ${tracks.indexOf(ts[0])} ${mute}`);
    },
    changeTrackSolo(ts: MixerTrack[], solo: boolean) {
      calls.push(`solo ${tracks.indexOf(ts[0])} ${solo}`);
    },
    midiLoaded: {
      on(handler: () => void) {
        handlers.push(handler);
        return () => handlers.splice(handlers.indexOf(handler), 1);
      },
    },
  };
  const mixerApi: MixerApi = api;
  return { api, mixerApi, calls, tracks };
}

test('mutes and solos without regenerating MIDI when programs are unchanged', async () => {
  const { mixerApi, calls } = fakeApi([29]);
  await new Mixer(mixerApi).apply([{ index: 0, mute: true, solo: false, program: 29 }]);
  expect(calls).toEqual(['mute 0 true', 'solo 0 false']);
});

test('a program change keeps position, mixer and loop', async () => {
  const { api, mixerApi, calls, tracks } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([{ index: 1, mute: true, solo: false, program: 29 }]);
  api.play();
  api.playbackRange = { startTick: 960, endTick: 3840 };
  api.tickPosition = 5000;
  api.isLooping = true;
  calls.length = 0;

  await mixer.apply([{ index: 0, mute: false, solo: false, program: 30 }]);

  expect(tracks[0].playbackInfo.program).toBe(30);
  expect(calls.filter((c) => c === 'loadMidi')).toHaveLength(1);
  expect(api.tickPosition).toBe(5000);
  expect(api.playbackRange).toEqual({ startTick: 960, endTick: 3840 });
  expect(api.isLooping).toBe(true);
  expect(calls.slice(calls.indexOf('loadMidi'))).toContain('mute 1 true');
  expect(calls.filter((c) => c === 'play')).toHaveLength(1);
});

test('an unknown track is an error', async () => {
  const { mixerApi } = fakeApi([29]);
  await expect(new Mixer(mixerApi).apply([{ index: 4, mute: false, solo: false, program: 29 }])).rejects.toThrow('no track 4');
});

test('a new song starts with no channel muted or soloed', async () => {
  const { mixerApi, calls } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([
    { index: 0, mute: false, solo: false, program: 29 },
    { index: 1, mute: true, solo: true, program: 29 },
  ]);
  calls.length = 0;

  mixer.newSong();

  expect(calls.sort()).toEqual([
    'channel mute 2 false',
    'channel mute 3 false',
    'channel solo 2 false',
    'channel solo 3 false',
  ]);
});

test('regenerate keeps position, mixer and loop', async () => {
  const { api, mixerApi, calls } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([{ index: 1, mute: true, solo: false, program: 29 }]);
  api.play();
  api.playbackRange = { startTick: 960, endTick: 3840 };
  api.tickPosition = 5000;
  api.isLooping = true;
  calls.length = 0;

  await mixer.regenerate();

  expect(calls.filter((c) => c === 'loadMidi')).toHaveLength(1);
  expect(api.tickPosition).toBe(5000);
  expect(api.playbackRange).toEqual({ startTick: 960, endTick: 3840 });
  expect(api.isLooping).toBe(true);
  expect(calls.slice(calls.indexOf('loadMidi'))).toContain('mute 1 true');
  expect(calls.filter((c) => c === 'play')).toHaveLength(1);
});

test('regenerate runs the load it is given', async () => {
  const { api, mixerApi, calls } = fakeApi([29]);
  api.tickPosition = 1234;
  let loads = 0;
  await new Mixer(mixerApi).regenerate(() => {
    loads++;
    api.loadMidiForScore();
  });
  expect(loads).toBe(1);
  expect(calls.filter((c) => c === 'loadMidi')).toHaveLength(1);
  expect(api.tickPosition).toBe(1234);
});
