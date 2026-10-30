import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { Mixer, type MixerApi, type MixerTrack } from '../src/mixer';

function fakeApi(programs: number[], volumes: number[] = programs.map(() => 12)) {
  const calls: string[] = [];
  const handlers: (() => void)[] = [];
  const tracks: MixerTrack[] = programs.map((program, i) => ({
    playbackInfo: { program, volume: volumes[i], primaryChannel: i * 2, secondaryChannel: i * 2 + 1 },
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
      setChannelVolume: (channel: number, volume: number) => calls.push(`channel volume ${channel} ${volume}`),
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
      queueMicrotask(() => [...handlers].forEach((h) => h()));
    },
    changeTrackMute(ts: MixerTrack[], mute: boolean) {
      calls.push(`mute ${tracks.indexOf(ts[0])} ${mute}`);
    },
    changeTrackSolo(ts: MixerTrack[], solo: boolean) {
      calls.push(`solo ${tracks.indexOf(ts[0])} ${solo}`);
    },
    changeTrackVolume(ts: MixerTrack[], factor: number) {
      calls.push(`volume ${tracks.indexOf(ts[0])} ${factor}`);
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
  await new Mixer(mixerApi).apply([{ index: 0, mute: true, solo: false, program: 29, volume: 12 }]);
  expect(calls).toEqual(['mute 0 true', 'solo 0 false']);
});

test('a program change keeps position, mixer and loop', async () => {
  const { api, mixerApi, calls, tracks } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([{ index: 1, mute: true, solo: false, program: 29, volume: 12 }]);
  api.play();
  api.playbackRange = { startTick: 960, endTick: 3840 };
  api.tickPosition = 5000;
  api.isLooping = true;
  calls.length = 0;

  await mixer.apply([{ index: 0, mute: false, solo: false, program: 30, volume: 12 }]);

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
  await expect(new Mixer(mixerApi).apply([{ index: 4, mute: false, solo: false, program: 29, volume: 12 }])).rejects.toThrow('no track 4');
});

test('a new song starts with no channel muted or soloed', async () => {
  const { mixerApi, calls } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([
    { index: 0, mute: false, solo: false, program: 29, volume: 12 },
    { index: 1, mute: true, solo: true, program: 29, volume: 12 },
  ]);
  calls.length = 0;

  mixer.newSong();

  expect(calls.sort()).toEqual([
    'channel mute 2 false',
    'channel mute 3 false',
    'channel solo 2 false',
    'channel solo 3 false',
    'channel volume 2 1',
    'channel volume 3 1',
  ]);
});

test('regenerate keeps position, mixer and loop', async () => {
  const { api, mixerApi, calls } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([{ index: 1, mute: true, solo: false, program: 29, volume: 12 }]);
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

const mix = (volume: number, program = 29) => ({ index: 0, mute: false, solo: false, program, volume });

test('a volume plays at its share of the MIDI level', async () => {
  const { mixerApi, calls, tracks } = fakeApi([29]);
  await new Mixer(mixerApi).apply([mix(6)]);
  // The synth sets a MIDI volume as its cube, (48 / 96)³, and a mix volume as is.
  expect(calls).toContain('volume 0 0.125');
  expect(tracks[0].playbackInfo.volume).toBe(6);
});

test('a volume survives new MIDI', async () => {
  const { mixerApi, calls, tracks } = fakeApi([29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([mix(6)]);
  calls.length = 0;
  await mixer.apply([mix(6, 30)]);
  expect(calls).toContain('loadMidi');
  expect(calls.filter((c) => c.startsWith('volume')).at(-1)).toBe('volume 0 1');
  expect(tracks[0].playbackInfo.volume).toBe(6);
});

test('a track made at 0 gets new MIDI for a volume', async () => {
  const { mixerApi, calls } = fakeApi([29], [0]);
  await new Mixer(mixerApi).apply([mix(8)]);
  expect(calls).toContain('loadMidi');
});

test("a new song resets the changed channels' volume", async () => {
  const { mixerApi, calls } = fakeApi([29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([mix(6)]);
  calls.length = 0;
  mixer.newSong();
  expect(calls).toEqual(expect.arrayContaining(['channel volume 0 1', 'channel volume 1 1']));
});

test('mixes follow their track when tracks move', async () => {
  const { mixerApi, calls, tracks } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([{ index: 0, mute: true, solo: false, program: 29, volume: 12 }]);
  tracks.reverse();
  calls.length = 0;
  await mixer.regenerate();
  expect(calls).toContain('mute 1 true');
  expect(calls).not.toContain('mute 0 true');
});

test("a removed track's mix is dropped", async () => {
  const { mixerApi, tracks } = fakeApi([29, 29, 29]);
  const mixer = new Mixer(mixerApi);
  await mixer.apply([0, 1, 2].map((index) => ({ index, mute: false, solo: true, program: 29, volume: 12 })));
  tracks.splice(2, 1);
  await expect(mixer.regenerate()).resolves.toBeUndefined();
});

test('the baked level is taken when the MIDI is made', async () => {
  const { mixerApi, calls, tracks } = fakeApi([29]);
  const mixer = new Mixer(mixerApi);
  const regenerated = mixer.regenerate();
  // A level set while the MIDI is still loading was not in it.
  tracks[0].playbackInfo.volume = 4;
  await regenerated;
  calls.length = 0;
  await mixer.apply([mix(4)]);
  expect(calls.find((c) => c.startsWith('volume'))).toBe(`volume 0 ${(32 / 96) ** 3}`);
});

test('a load that makes MIDI twice restores after the second', async () => {
  const { api, mixerApi } = fakeApi([29]);
  const handlers: (() => void)[] = [];
  api.midiLoaded = {
    on(handler: () => void) {
      handlers.push(handler);
      return () => handlers.splice(handlers.indexOf(handler), 1);
    },
  };
  // alphaTab moves the position back when each MIDI arrives, the second later.
  let loads = 0;
  api.loadMidiForScore = () => {
    const arrive = () => {
      api.tickPosition = 0;
      [...handlers].forEach((h) => h());
    };
    if (loads++ === 0) queueMicrotask(arrive);
    else setTimeout(arrive, 0);
  };
  api.tickPosition = 1234;
  const mixer = new Mixer(mixerApi);
  await mixer.regenerate(() => {
    mixerApi.loadMidiForScore();
    mixerApi.loadMidiForScore();
  });
  await new Promise((r) => setTimeout(r, 10));
  expect(api.tickPosition).toBe(1234);
});

test('resuming after new MIDI plays no count-in', async () => {
  const { api, mixerApi } = fakeApi([29]);
  const withCountIn = Object.assign(api, { countInVolume: 1 });
  const counts: number[] = [];
  const play = api.play.bind(api);
  api.play();
  withCountIn.play = () => {
    counts.push(withCountIn.countInVolume);
    play();
  };
  await new Mixer(mixerApi).regenerate();
  expect(counts).toEqual([0]);
  expect(withCountIn.countInVolume).toBe(1);
});
