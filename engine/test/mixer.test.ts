import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { Mixer, type MixerApi, type MixerTrack } from '../src/mixer';

function fakeApi(programs: number[]) {
  const calls: string[] = [];
  const handlers: (() => void)[] = [];
  const tracks: MixerTrack[] = programs.map((program) => ({ playbackInfo: { program } }));
  const api = {
    score: { tracks },
    tickPosition: 0,
    playerState: alphaTab.synth.PlayerState.Paused as alphaTab.synth.PlayerState,
    isLooping: false as boolean,
    playbackRange: null as { startTick: number; endTick: number } | null,
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
  api.tickPosition = 5000;
  api.playbackRange = { startTick: 960, endTick: 3840 };
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
