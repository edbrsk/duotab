import * as alphaTab from '@coderline/alphatab';

import { applyProgram, type ProgramTrack } from './instrument';
import { storedFromPan, storedFromTrackDb } from './mix_values';
import type { TrackMix } from './protocol';

export type MixerTrack = ProgramTrack & {
  playbackInfo: { program: number; volume: number; balance: number; primaryChannel: number; secondaryChannel: number };
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

  /** The shift each channel was last given. */
  private readonly pans = new Map<number, number>();

  /**
   * `pan` shifts a channel's pan in the synth worker, which keeps the song's
   * own pan changes moving under it; null is no shift.
   */
  constructor(
    private readonly api: MixerApi,
    private readonly pan: (channel: number, shift: number | null) => void,
  ) {
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
    for (const channel of this.pans.keys()) this.pan(channel, null);
    this.pans.clear();
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
      // No factor lifts a track whose MIDI was made silent, so it is made at 0 dB.
      if (this.baked.get(track) === 0 && mix.volumeDb !== null) {
        info.volume = REFERENCE_VOLUME;
        newMidi = true;
      }
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

  /**
   * Gives each mix to the track that replaces its own, as undo and redo
   * rebuild every track. Tracks are matched by primary MIDI channel, as
   * undo can move them.
   */
  carry(to: MixerTrack[]): void {
    const unmatched = [...to];
    for (const [track, mix] of [...this.mixes]) {
      this.mixes.delete(track);
      const at = unmatched.findIndex((t) => t.playbackInfo.primaryChannel === track.playbackInfo.primaryChannel);
      if (at < 0) continue;
      const [target] = unmatched.splice(at, 1);
      this.mixes.set(target, { ...mix, index: to.indexOf(target) });
    }
  }

  /** Runs `run` with each mixed track's file volume and pan set to its fader and knob, as a file is written. */
  withFileLevels<T>(run: () => T): T {
    const kept = [...this.mixes].map(([track, mix]) => {
      const info = track.playbackInfo;
      const was = { volume: info.volume, balance: info.balance };
      info.volume = storedFromTrackDb(mix.volumeDb) * 16;
      info.balance = storedFromPan(mix.pan) * 16;
      return { info, was };
    });
    try {
      return run();
    } finally {
      for (const { info, was } of kept) Object.assign(info, was);
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
      const factor = levelFactor(mix.volumeDb, this.baked.get(track) ?? track.playbackInfo.volume);
      if (this.factors.get(track) !== factor && !(factor === 1 && !this.factors.has(track))) {
        this.api.changeTrackVolume([track], factor);
        this.factors.set(track, factor);
      }
      const shift = mix.pan - midiPan(track.playbackInfo.balance);
      for (const channel of [track.playbackInfo.primaryChannel, track.playbackInfo.secondaryChannel]) {
        if (this.pans.get(channel) === shift) continue;
        this.pan(channel, shift);
        this.pans.set(channel, shift);
      }
      if (mix.mute || mix.solo || factor !== 1) {
        this.changedChannels.add(track.playbackInfo.primaryChannel);
        this.changedChannels.add(track.playbackInfo.secondaryChannel);
      }
    }
  }
}

/** Where the synth places a channel of 0–16 balance, −1…1: alphaTab writes it as MIDI pan `balance × 8`. */
const midiPan = (balance: number): number => (2 * Math.min(16383, balance * 8 * 128)) / 16383 - 1;

/** The alphaTab volume whose MIDI plays at 0 dB: MIDI volume 96, as Guitar Pro's default level. */
const REFERENCE_VOLUME = 12;

/**
 * The mix volume that plays `db` over MIDI made at `baked`. alphaTab writes a
 * track volume as MIDI volume `volume × 8`, which the synth applies as its
 * cube; a mix volume applies as is.
 */
function levelFactor(db: number | null, baked: number): number {
  if (db === null) return 0;
  if (baked === 0) return 1;
  const midi = (v: number) => Math.min(127, v * 8);
  return 10 ** (db / 20) * (midi(REFERENCE_VOLUME) / midi(baked)) ** 3;
}
