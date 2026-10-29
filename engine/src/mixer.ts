import * as alphaTab from '@coderline/alphatab';

import type { TrackMix } from './protocol';

export type MixerTrack = { playbackInfo: { program: number } };

/** The part of AlphaTabApi the mixer drives. */
export interface MixerApi {
  readonly score: { tracks: MixerTrack[] } | null;
  tickPosition: number;
  readonly playerState: alphaTab.synth.PlayerState;
  isLooping: boolean;
  playbackRange: { startTick: number; endTick: number } | null;
  play(): unknown;
  pause(): void;
  loadMidiForScore(): void;
  changeTrackMute(tracks: MixerTrack[], mute: boolean): void;
  changeTrackSolo(tracks: MixerTrack[], solo: boolean): void;
  readonly midiLoaded: { on(handler: () => void): () => void };
}

export class Mixer {
  private readonly mixes = new Map<number, TrackMix>();

  constructor(private readonly api: MixerApi) {}

  /** Forgets the previous song's mix. */
  reset(): void {
    this.mixes.clear();
  }

  async apply(mixes: TrackMix[]): Promise<void> {
    const tracks = this.api.score?.tracks ?? [];
    for (const mix of mixes) if (!tracks[mix.index]) throw new Error(`no track ${mix.index}`);

    let programChanged = false;
    for (const mix of mixes) {
      const info = tracks[mix.index].playbackInfo;
      if (info.program !== mix.program) {
        info.program = mix.program;
        programChanged = true;
      }
      this.mixes.set(mix.index, mix);
    }
    // A new program needs new MIDI, which resets the player's position and channels.
    if (programChanged) await this.reloadMidi(tracks);
    this.send(tracks, mixes);
  }

  private async reloadMidi(tracks: MixerTrack[]): Promise<void> {
    const api = this.api;
    const tick = api.tickPosition;
    const wasPlaying = api.playerState === alphaTab.synth.PlayerState.Playing;
    const range = api.playbackRange;
    const looping = api.isLooping;
    if (wasPlaying) api.pause();
    const loaded = new Promise<void>((resolve) => {
      const off = api.midiLoaded.on(() => {
        off();
        resolve();
      });
    });
    api.loadMidiForScore();
    await loaded;
    api.tickPosition = tick;
    api.playbackRange = range;
    api.isLooping = looping;
    this.send(tracks, [...this.mixes.values()]);
    if (wasPlaying) api.play();
  }

  private send(tracks: MixerTrack[], mixes: TrackMix[]): void {
    for (const mix of mixes) {
      this.api.changeTrackMute([tracks[mix.index]], mix.mute);
      this.api.changeTrackSolo([tracks[mix.index]], mix.solo);
    }
  }
}
