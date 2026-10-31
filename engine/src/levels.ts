import type { LevelsPayload } from './protocol';
import type { LevelFrame } from './worker/synth_hooks';

type Channels = { primaryChannel: number; secondaryChannel: number };

const FLOOR_DB = -60;

const dbfs = (peak: number, gain: number): number | null => {
  const db = 20 * Math.log10(peak * gain);
  return db >= FLOOR_DB ? Math.round(db * 10) / 10 : null;
};

const pair = (left: number, right: number, gain: number): [number, number] | null => {
  const l = dbfs(left, gain);
  const r = dbfs(right, gain);
  return l === null && r === null ? null : [l ?? FLOOR_DB, r ?? FLOOR_DB];
};

/** The player time heard at `time`, which alphaTab counts in real milliseconds at any speed. */
export const heardAt = (time: number, latencyMs: number): number => time - latencyMs;

/**
 * The synth worker renders ahead of the speaker, so its level frames wait
 * here until playback reaches them. Gains are linear, applied after the synth.
 */
export class LevelMeter {
  private frames: (LevelFrame & { masterGain: number })[] = [];
  private posted = Number.NEGATIVE_INFINITY;

  /** Posts at most every `everyMs`; frames due in between wait for the next. */
  constructor(private readonly everyMs = 40) {}

  /** `masterGain` is the one the frame's sound was given, which a fader move since hasn't reached. */
  add(frame: LevelFrame, masterGain: number): void {
    this.frames.push({ ...frame, masterGain });
  }

  clear(): void {
    this.frames = [];
  }

  /** The loudest of the frames that have played by `time`, or null if none has or it's too soon to post. */
  release(time: number, tracks: Channels[], trackGain: number, now: number): LevelsPayload | null {
    if (now - this.posted < this.everyMs) return null;
    const due = this.frames.filter((f) => f.time <= time);
    if (due.length === 0) return null;
    this.posted = now;
    this.frames = this.frames.filter((f) => f.time > time);
    const peaks = new Map<number, [number, number]>();
    const master: [number, number] = [0, 0];
    for (const frame of due) {
      for (const [channel, left, right] of frame.channels) {
        const peak = peaks.get(channel) ?? [0, 0];
        peaks.set(channel, [Math.max(peak[0], left), Math.max(peak[1], right)]);
      }
      master[0] = Math.max(master[0], frame.master[0] * frame.masterGain);
      master[1] = Math.max(master[1], frame.master[1] * frame.masterGain);
    }
    return {
      tracks: tracks.map((t) => {
        const a = peaks.get(t.primaryChannel) ?? [0, 0];
        const b = peaks.get(t.secondaryChannel) ?? [0, 0];
        return pair(Math.max(a[0], b[0]), Math.max(a[1], b[1]), trackGain);
      }),
      master: pair(master[0], master[1], 1),
    };
  }
}
