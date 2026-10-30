/**
 * Raises the synth's output and turns peaks down to the ceiling, for
 * interleaved stereo. GeneralUser GS plays 6–12 dB below what the songs
 * were mixed for, and the speaker clips anything above 1.
 */
export class Limiter {
  private reduction = 1;
  private readonly release: number;

  constructor(
    sampleRate: number,
    public gain = 2,
    private readonly ceiling = 0.95,
    releaseSeconds = 0.1,
  ) {
    this.release = 1 - Math.exp(-1 / (releaseSeconds * sampleRate));
  }

  process(samples: Float32Array): void {
    for (let i = 0; i + 1 < samples.length; i += 2) {
      // Linked, so a loud channel doesn't move the stereo image.
      const peak = Math.max(Math.abs(samples[i]), Math.abs(samples[i + 1])) * this.gain;
      const target = peak > this.ceiling ? this.ceiling / peak : 1;
      this.reduction = target < this.reduction ? target : this.reduction + (target - this.reduction) * this.release;
      const scale = this.gain * this.reduction;
      samples[i] *= scale;
      samples[i + 1] *= scale;
    }
  }
}

/** Runs every block the player sends to the speaker through `limiter`. */
export function limitOutput(output: { addSamples(samples: Float32Array): void }, limiter: Limiter): void {
  const addSamples = output.addSamples.bind(output);
  output.addSamples = (samples) => {
    limiter.process(samples);
    addSamples(samples);
  };
}
