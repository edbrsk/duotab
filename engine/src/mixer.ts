import * as alphaTab from '@coderline/alphatab';

import { applyProgram, type ProgramTrack } from './instrument';
import type { TrackMix } from './protocol';

export type MixerTrack = ProgramTrack & {
  playbackInfo: { program: number; volume: number; primaryChannel: number; secondaryChannel: number };
};

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
  countInVolume?: number;
  changeTrackMute(tracks: MixerTrack[], mute: boolean): void;
  changeTrackSolo(tracks: MixerTrack[], solo: boolean): void;
  /** A multiplier on the volume the MIDI was made with. */
  changeTrackVolume(tracks: MixerTrack[], factor: number): void;
  readonly midiLoaded: { on(handler: () => void): () => void };
  readonly player: {
    setChannelMute(channel: number, mute: boolean): void;
    setChannelSolo(channel: number, solo: boolean): void;
    setChannelVolume(channel: number, volume: number): void;
  } | null;
}

export class Mixer {
  /** By track, so a mix stays with its track when tracks move or go. */
  private readonly mixes = new Map<MixerTrack, TrackMix>();
  private readonly changedChannels = new Set<number>();
  /** The volume each track's current MIDI was made with. */
  private readonly baked = new WeakMap<MixerTrack, number>();
  private readonly factors = new WeakMap<MixerTrack, number>();
  /** The volumes the MIDI being made was made with, until it arrives. */
  private making: Map<MixerTrack, number> | null = null;
  /** Regenerates run one at a time; each reads the player as the last left it. */
  private queue: Promise<void> = Promise.resolve();

  constructor(private readonly api: MixerApi) {
    api.midiLoaded.on(() => {
      for (const track of api.score?.tracks ?? []) {
        this.baked.set(track, this.making?.get(track) ?? track.playbackInfo.volume);
        // The player keeps a channel's mix volume across MIDI loads.
        this.factors.set(track, Number.NaN);
      }
    });
  }

  /**
   * Call once the next song has loaded. alphaTab keeps mute and solo per MIDI
   * channel across songs, so a solo left on would silence the new song.
   */
  newSong(): void {
    for (const channel of this.changedChannels) {
      this.api.player?.setChannelMute(channel, false);
      this.api.player?.setChannelSolo(channel, false);
      this.api.player?.setChannelVolume(channel, 1);
    }
    this.changedChannels.clear();
    this.mixes.clear();
  }

  async apply(mixes: TrackMix[]): Promise<void> {
    const tracks = this.api.score?.tracks ?? [];
    for (const mix of mixes) if (!tracks[mix.index]) throw new Error(`no track ${mix.index}`);

    let newMidi = false;
    for (const mix of mixes) {
      const track = tracks[mix.index];
      const info = track.playbackInfo;
      if (!this.baked.has(track)) this.baked.set(track, info.volume);
      if (applyProgram(track, mix.program)) newMidi = true;
      info.volume = mix.volume;
      // No factor lifts a track whose MIDI was made silent.
      if (this.baked.get(track) === 0 && mix.volume > 0) newMidi = true;
      this.mixes.set(track, mix);
    }
    // A new program needs new MIDI, which resets the player's position and channels.
    if (newMidi) await this.regenerate();
    this.send();
  }

  /**
   * New MIDI for the song, keeping position, playing state, loop and mix.
   * `load` may make MIDI more than once (alphaTab's renderScore of a new score
   * does); the position goes back after the last.
   */
  regenerate(load: () => void = () => this.api.loadMidiForScore()): Promise<void> {
    const run = this.queue.then(() => this.run(load));
    this.queue = run.catch(() => {});
    return run;
  }

  private async run(load: () => void): Promise<void> {
    const api = this.api;
    const tick = api.tickPosition;
    const wasPlaying = api.playerState === alphaTab.synth.PlayerState.Playing;
    const range = api.playbackRange;
    const looping = api.isLooping;
    if (wasPlaying) api.pause();
    this.making = new Map((api.score?.tracks ?? []).map((t) => [t, t.playbackInfo.volume]));
    let made = 0;
    let arrived = 0;
    let done: () => void = () => {};
    const loaded = new Promise<void>((resolve) => (done = resolve));
    const off = api.midiLoaded.on(() => {
      arrived++;
      if (arrived >= made) done();
    });
    // alphaTab calls loadMidiForScore on itself, so counting the calls counts the loads.
    const real = api.loadMidiForScore;
    api.loadMidiForScore = () => {
      made++;
      real.call(api);
    };
    try {
      try {
        load();
      } finally {
        api.loadMidiForScore = real;
      }
      if (made === 0) made = 1;
      if (arrived >= made) done();
      await loaded;
    } finally {
      off();
      this.making = null;
    }
    // Setting a range seeks to its start, so the position goes back last.
    api.playbackRange = range;
    api.isLooping = looping;
    api.tickPosition = tick;
    this.send();
    if (wasPlaying) {
      // Playback resumes where it was; a count-in belongs to a fresh start.
      const countIn = api.countInVolume;
      if (countIn !== undefined) api.countInVolume = 0;
      api.play();
      if (countIn !== undefined) api.countInVolume = countIn;
    }
  }

  private send(): void {
    const tracks = this.api.score?.tracks ?? [];
    for (const [track, mix] of this.mixes) {
      // A track removed, or replaced by undo, takes its mix with it.
      if (!tracks.includes(track)) {
        this.mixes.delete(track);
        continue;
      }
      this.api.changeTrackMute([track], mix.mute);
      this.api.changeTrackSolo([track], mix.solo);
      const factor = volumeFactor(mix.volume, this.baked.get(track) ?? track.playbackInfo.volume);
      if (this.factors.get(track) !== factor && !(factor === 1 && !this.factors.has(track))) {
        this.api.changeTrackVolume([track], factor);
        this.factors.set(track, factor);
      }
      if (mix.mute || mix.solo || factor !== 1) {
        this.changedChannels.add(track.playbackInfo.primaryChannel);
        this.changedChannels.add(track.playbackInfo.secondaryChannel);
      }
    }
  }
}

/**
 * The mix volume that sounds like MIDI made at `volume`, given MIDI made at
 * `baked`. alphaTab writes a track volume as MIDI volume `volume × 8`, which
 * the synth applies as its cube; a mix volume applies as is.
 */
function volumeFactor(volume: number, baked: number): number {
  if (baked === 0) return 1;
  const midi = (v: number) => Math.min(127, v * 8);
  return (midi(volume) / midi(baked)) ** 3;
}
