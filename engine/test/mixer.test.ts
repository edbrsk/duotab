import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { Mixer, type MixerApi, type MixerTrack } from '../src/mixer';

const noPan = () => {};

function fakeApi(programs: number[], volumes: number[] = programs.map(() => 12)) {
  const calls: string[] = [];
  const handlers: (() => void)[] = [];
  const tracks: MixerTrack[] = programs.map((program, i) => ({
    playbackInfo: { program, volume: volumes[i], balance: 8, primaryChannel: i * 2, secondaryChannel: i * 2 + 1 },
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
  const pans: string[] = [];
  const pan = (channel: number, value: number | null) => pans.push(`pan ${channel} ${value}`);
  return { api, mixerApi, calls, tracks, pan, pans };
}

test('mutes and solos without regenerating MIDI when programs are unchanged', async () => {
  const { mixerApi, calls, pan } = fakeApi([29]);
  await new Mixer(mixerApi, pan).apply([{ index: 0, mute: true, solo: false, program: 29, volumeDb: 0, pan: 0 }]);
  expect(calls).toEqual(['mute 0 true', 'solo 0 false']);
});

test('a program change keeps position, mixer and loop', async () => {
  const { api, mixerApi, calls, tracks } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi, noPan);
  await mixer.apply([{ index: 1, mute: true, solo: false, program: 29, volumeDb: 0, pan: 0 }]);
  api.play();
  api.playbackRange = { startTick: 960, endTick: 3840 };
  api.tickPosition = 5000;
  api.isLooping = true;
  calls.length = 0;

  await mixer.apply([{ index: 0, mute: false, solo: false, program: 30, volumeDb: 0, pan: 0 }]);

  expect(tracks[0].playbackInfo.program).toBe(30);
  expect(calls.filter((c) => c === 'loadMidi')).toHaveLength(1);
  expect(api.tickPosition).toBe(5000);
  expect(api.playbackRange).toEqual({ startTick: 960, endTick: 3840 });
  expect(api.isLooping).toBe(true);
  expect(calls.slice(calls.indexOf('loadMidi'))).toContain('mute 1 true');
  expect(calls.filter((c) => c === 'play')).toHaveLength(1);
});

test('an unknown track is an error', async () => {
  const { mixerApi, pan } = fakeApi([29]);
  await expect(new Mixer(mixerApi, pan).apply([{ index: 4, mute: false, solo: false, program: 29, volumeDb: 0, pan: 0 }])).rejects.toThrow('no track 4');
});

test('a new song starts with no channel muted or soloed', async () => {
  const { mixerApi, calls, pan } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([
    { index: 0, mute: false, solo: false, program: 29, volumeDb: 0, pan: 0 },
    { index: 1, mute: true, solo: true, program: 29, volumeDb: 0, pan: 0 },
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
  const mixer = new Mixer(mixerApi, noPan);
  await mixer.apply([{ index: 1, mute: true, solo: false, program: 29, volumeDb: 0, pan: 0 }]);
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
  await new Mixer(mixerApi, noPan).regenerate(() => {
    loads++;
    api.loadMidiForScore();
  });
  expect(loads).toBe(1);
  expect(calls.filter((c) => c === 'loadMidi')).toHaveLength(1);
  expect(api.tickPosition).toBe(1234);
});

const mix = (volumeDb: number | null, program = 29, pan = 0) => ({ index: 0, mute: false, solo: false, program, volumeDb, pan });
const lastVolume = (calls: string[]) => Number(calls.filter((c) => c.startsWith('volume 0 ')).at(-1)!.split(' ')[2]);

test("a level plays as its dB over the MIDI's", async () => {
  const at12 = fakeApi([29]);
  await new Mixer(at12.mixerApi, at12.pan).apply([mix(-6)]);
  expect(lastVolume(at12.calls)).toBeCloseTo(10 ** (-6 / 20), 6);
  const at10 = fakeApi([29], [10]);
  await new Mixer(at10.mixerApi, at10.pan).apply([mix(0)]);
  // The synth cubes MIDI volume: 0 dB is MIDI volume 96, and 10 makes 80.
  expect(lastVolume(at10.calls)).toBeCloseTo((96 / 80) ** 3, 6);
  const off = fakeApi([29]);
  await new Mixer(off.mixerApi, off.pan).apply([mix(null)]);
  expect(lastVolume(off.calls)).toBe(0);
});

test('a level survives new MIDI', async () => {
  const { mixerApi, calls, tracks, pan } = fakeApi([29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([mix(-6)]);
  calls.length = 0;
  await mixer.apply([mix(-6, 30)]);
  expect(calls).toContain('loadMidi');
  expect(lastVolume(calls)).toBeCloseTo(10 ** (-6 / 20), 6);
  expect(tracks[0].playbackInfo.volume).toBe(12);
});

test('a silent file track is baked at 0 dB once its fader rises', async () => {
  const { mixerApi, calls, tracks, pan } = fakeApi([29], [0]);
  await new Mixer(mixerApi, pan).apply([mix(-6)]);
  expect(calls).toContain('loadMidi');
  expect(tracks[0].playbackInfo.volume).toBe(12);
});

test("pan goes to both of a track's channels", async () => {
  const { mixerApi, pans, pan } = fakeApi([29]);
  await new Mixer(mixerApi, pan).apply([mix(0, 29, -0.5)]);
  expect(pans.map((p) => p.replace(/(-?\d+\.\d{4})\d+/, '$1'))).toEqual(['pan 0 -0.5000', 'pan 1 -0.5000']);
});

test('pan moves a track from where its MIDI places it', async () => {
  const { mixerApi, tracks, pans, pan } = fakeApi([29]);
  tracks[0].playbackInfo.balance = 0;
  await new Mixer(mixerApi, pan).apply([mix(0, 29, 0.5)]);
  expect(pans).toEqual(expect.arrayContaining(['pan 0 1.5', 'pan 1 1.5']));
});

test('a new song drops the pans', async () => {
  const { mixerApi, pans, pan } = fakeApi([29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([mix(0, 29, -0.5)]);
  pans.length = 0;
  mixer.newSong();
  expect(pans).toEqual(expect.arrayContaining(['pan 0 null', 'pan 1 null']));
});

test("export writes the faders and leaves the MIDI's level", async () => {
  const { mixerApi, tracks, pan } = fakeApi([29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([mix(-6, 29, -1)]);
  const written = mixer.withFileLevels(() => ({ ...tracks[0].playbackInfo }));
  expect(written.volume).toBeCloseTo(10.88, 6);
  expect(written.balance).toBe(0);
  expect(tracks[0].playbackInfo.volume).toBe(12);
  expect(tracks[0].playbackInfo.balance).toBe(8);
});

test("a new song resets the changed channels' volume", async () => {
  const { mixerApi, calls, pan } = fakeApi([29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([mix(-6)]);
  calls.length = 0;
  mixer.newSong();
  expect(calls).toEqual(expect.arrayContaining(['channel volume 0 1', 'channel volume 1 1']));
});

test('mixes follow their track when tracks move', async () => {
  const { mixerApi, calls, tracks, pan } = fakeApi([29, 29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([{ index: 0, mute: true, solo: false, program: 29, volumeDb: 0, pan: 0 }]);
  tracks.reverse();
  calls.length = 0;
  await mixer.regenerate();
  expect(calls).toContain('mute 1 true');
  expect(calls).not.toContain('mute 0 true');
});

test("a removed track's mix is dropped", async () => {
  const { mixerApi, tracks, pan } = fakeApi([29, 29, 29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([0, 1, 2].map((index) => ({ index, mute: false, solo: true, program: 29, volumeDb: 0, pan: 0 })));
  tracks.splice(2, 1);
  await expect(mixer.regenerate()).resolves.toBeUndefined();
});

test('the baked level is taken when the MIDI is made', async () => {
  const { mixerApi, calls, tracks, pan } = fakeApi([29]);
  const mixer = new Mixer(mixerApi, pan);
  // A level set while the MIDI is still loading was not in it.
  await mixer.regenerate(() => {
    mixerApi.loadMidiForScore();
    tracks[0].playbackInfo.volume = 4;
  });
  calls.length = 0;
  await mixer.apply([mix(-6)]);
  // Made at 12, not 4: a factor against 4 would be 27 times too loud.
  expect(lastVolume(calls)).toBeCloseTo(10 ** (-6 / 20), 6);
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
  const mixer = new Mixer(mixerApi, noPan);
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
  await new Mixer(mixerApi, noPan).regenerate();
  expect(counts).toEqual([0]);
  expect(withCountIn.countInVolume).toBe(1);
});

test('two regenerates at once keep playing from where they were', async () => {
  const { api, mixerApi } = fakeApi([29]);
  const handlers: (() => void)[] = [];
  api.midiLoaded = {
    on(handler: () => void) {
      handlers.push(handler);
      return () => handlers.splice(handlers.indexOf(handler), 1);
    },
  };
  // The player's MIDI arrives later and moves the position back.
  api.loadMidiForScore = () =>
    setTimeout(() => {
      api.tickPosition = 0;
      [...handlers].forEach((h) => h());
    }, 1);
  api.play();
  api.tickPosition = 5000;
  const mixer = new Mixer(mixerApi, noPan);
  await Promise.all([mixer.regenerate(), mixer.regenerate()]);
  await new Promise((r) => setTimeout(r, 10));
  expect(api.tickPosition).toBe(5000);
  expect(api.playerState).toBe(alphaTab.synth.PlayerState.Playing);
});

test('an undo keeps the mixes on the tracks it brings back', async () => {
  const { api, mixerApi, pan } = fakeApi([29]);
  const mixer = new Mixer(mixerApi, pan);
  await mixer.apply([mix(-6, 29, -1)]);
  // Undo rebuilds the song: the same tracks, as new objects.
  const restored: MixerTrack[] = api.score.tracks.map((t) => ({ playbackInfo: { ...t.playbackInfo } }));
  mixer.carry(restored);
  api.score = { tracks: restored };
  await mixer.regenerate();
  const written = mixer.withFileLevels(() => ({ ...restored[0].playbackInfo }));
  expect(written.volume).toBeCloseTo(10.88, 6);
  expect(written.balance).toBe(0);
});
