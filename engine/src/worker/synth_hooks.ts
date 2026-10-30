import type * as alphaTab from '@coderline/alphatab';

/** Peaks are linear, before the page's gain; `time` is the sequencer's when the block ends. */
export type LevelFrame = {
  cmd: 'duoscore.levels';
  time: number;
  channels: [channel: number, left: number, right: number][];
  master: [number, number];
};

/** `pan` −1…1; null gives the channel the song's own pan back. */
export type PanMessage = { cmd: 'duoscore.pan'; channel: number; pan: number | null };

// The parts of alphaTab 1.6.1's TinySoundFont and Voice the hooks reach (not exported).
type Voice = {
  playingChannel: number;
  render(f: unknown, out: Float32Array, offset: number, frames: number, muted: boolean): void;
};
type Synth = {
  _voices: Voice[];
  _channels: { channelList: { midiPan: number }[] } | null;
  channelSetPan(channel: number, pan: number): void;
  synthesize(buffer: Float32Array | null, offset: number, frames: number): unknown;
};
type Player = { state: alphaTab.synth.PlayerState; sequencer: { currentTime: number }; onSampleRequest(): void };

/**
 * Makes every synth in this worker measure each MIDI channel's peak after its
 * fader and pan, and let an owner's pan override the song's. Posts one frame
 * per block the player renders while playing.
 */
export function installSynthHooks(at: typeof alphaTab, post: (frame: LevelFrame) => void) {
  // The exporter is the one way to get alphaTab's TinySoundFont without an audio output.
  const exporter = at.synth.AlphaSynth.prototype.exportAudio.call(
    { synthesizer: { presets: [] } } as never,
    new at.synth.AudioExportOptions(),
    new at.midi.MidiFile(),
    [],
    new Map(),
  ) as unknown as { _synth: Synth };
  const synthProto = Object.getPrototypeOf(exporter._synth) as Synth;
  const overrides = new Map<number, number>();
  const synths = new Set<Synth>();
  const channels = new Map<number, [number, number]>();
  const master: [number, number] = [0, 0];
  let scratch = new Float32Array(256);
  // Each channel's voices summed over the block being synthesized: a chord's
  // level is its strings together, not its loudest string.
  const sums = new Map<number, Float32Array>();
  const touched = new Set<number>();
  let block: { offset: number; length: number } | null = null;

  const { channelSetPan, synthesize } = synthProto;
  synthProto.channelSetPan = function (this: Synth, channel, pan) {
    synths.add(this);
    channelSetPan.call(this, channel, overrides.get(channel) ?? pan);
  };

  let voicesHooked = false;
  const hookVoices = (proto: Voice) => {
    voicesHooked = true;
    const { render } = proto;
    proto.render = function (this: Voice, f, out, offset, frames, muted) {
      const length = frames * 2;
      if (!block) {
        render.call(this, f, out, offset, frames, muted);
        return;
      }
      if (scratch.length < length) scratch = new Float32Array(length);
      for (let i = 0; i < length; i++) scratch[i] = out[offset + i];
      render.call(this, f, out, offset, frames, muted);
      let sum = sums.get(this.playingChannel);
      if (!sum || sum.length < block.length) {
        const grown = new Float32Array(block.length);
        if (sum) grown.set(sum);
        sums.set(this.playingChannel, (sum = grown));
      }
      const at = offset - block.offset;
      for (let i = 0; i < length; i++) sum[at + i] += out[offset + i] - scratch[i];
      touched.add(this.playingChannel);
    };
  };

  synthProto.synthesize = function (this: Synth, buffer, offset, frames) {
    synths.add(this);
    block = buffer ? { offset, length: frames * 2 } : null;
    let result: unknown;
    try {
      result = synthesize.call(this, buffer, offset, frames);
    } finally {
      const length = block?.length ?? 0;
      block = null;
      for (const channel of touched) {
        const sum = sums.get(channel)!;
        let left = 0;
        let right = 0;
        for (let i = 0; i < length; i += 2) {
          left = Math.max(left, Math.abs(sum[i]));
          right = Math.max(right, Math.abs(sum[i + 1]));
        }
        sum.fill(0, 0, length);
        if (left === 0 && right === 0) continue;
        const peak = channels.get(channel) ?? [0, 0];
        peak[0] = Math.max(peak[0], left);
        peak[1] = Math.max(peak[1], right);
        channels.set(channel, peak);
      }
      touched.clear();
    }
    if (!voicesHooked && this._voices.length > 0) hookVoices(Object.getPrototypeOf(this._voices[0]) as Voice);
    if (buffer) {
      for (let i = offset; i < offset + frames * 2; i += 2) {
        master[0] = Math.max(master[0], Math.abs(buffer[i]));
        master[1] = Math.max(master[1], Math.abs(buffer[i + 1]));
      }
    }
    return result;
  };

  const take = () => {
    const frame = { channels: [...channels].map(([c, [l, r]]): [number, number, number] => [c, l, r]), master: [master[0], master[1]] as [number, number] };
    channels.clear();
    master[0] = master[1] = 0;
    return frame;
  };

  const playerProto = at.synth.AlphaSynthBase.prototype as unknown as Player;
  const { onSampleRequest } = playerProto;
  playerProto.onSampleRequest = function (this: Player) {
    onSampleRequest.call(this);
    if (this.state === at.synth.PlayerState.Playing) post({ cmd: 'duoscore.levels', time: this.sequencer.currentTime, ...take() });
    else take();
  };

  return {
    take,
    setPan(channel: number, pan: number | null) {
      if (pan === null) overrides.delete(channel);
      else overrides.set(channel, 0.5 + pan / 2);
      for (const synth of synths) {
        const songPan = (synth._channels?.channelList[channel]?.midiPan ?? 8192) / 16383;
        channelSetPan.call(synth, channel, overrides.get(channel) ?? songPan);
      }
    },
  };
}
