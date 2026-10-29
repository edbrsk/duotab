import * as alphaTab from '@coderline/alphatab';

import type { TrackMix } from './protocol';

export type MixerTrack = { playbackInfo: { program: number; primaryChannel: number; secondaryChannel: number } };

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
  readonly player: {
    setChannelMute(channel: number, mute: boolean): void;
    setChannelSolo(channel: number, solo: boolean): void;
  } | null;
}

export class Mixer {
  private readonly mixes = new Map<number, TrackMix>();
  private readonly changedChannels = new Set<number>();

  constructor(private readonly api: MixerApi) {}

  /**
   * Call once the next song has loaded. alphaTab keeps mute and solo per MIDI
   * channel across songs, so a solo left on would silence the new song.
   */
  newSong(): void {
    for (const channel of this.changedChannels) {
      this.api.player?.setChannelMute(channel, false);
      this.api.player?.setChannelSolo(channel, false);
    }
    this.changedChannels.clear();
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
    if (programChanged) await this.regenerate();
    this.send(this.api.score?.tracks ?? tracks, mixes);
  }

  /**
   * New MIDI for the song, keeping position, playing state, loop and mix.
   * `load` must lead to one `midiLoaded`; replacing the score (undo) loads its own.
   */
  async regenerate(load: () => void = () => this.api.loadMidiForScore()): Promise<void> {
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
    load();
    await loaded;
    // Setting a range seeks to its start, so the position goes back last.
    api.playbackRange = range;
    api.isLooping = looping;
    api.tickPosition = tick;
    this.send(api.score?.tracks ?? [], [...this.mixes.values()]);
    if (wasPlaying) api.play();
  }

  private send(tracks: MixerTrack[], mixes: TrackMix[]): void {
    for (const mix of mixes) {
      const track = tracks[mix.index];
      this.api.changeTrackMute([track], mix.mute);
      this.api.changeTrackSolo([track], mix.solo);
      if (mix.mute || mix.solo) {
        this.changedChannels.add(track.playbackInfo.primaryChannel);
        this.changedChannels.add(track.playbackInfo.secondaryChannel);
      }
    }
  }
}
