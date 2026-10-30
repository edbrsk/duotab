import { expect, test } from 'vitest';

import { Limiter, limitOutput } from '../src/output_level';

// At 1000 Hz the 0.1 s release is 100 frames.
const limiter = () => new Limiter(1000);

const frames = (count: number, value: number) => new Float32Array(count * 2).fill(value);

test('a quiet block plays at twice its level', () => {
  const samples = new Float32Array([0.1, -0.1, 0.2, -0.2]);
  limiter().process(samples);
  [0.2, -0.2, 0.4, -0.4].forEach((v, i) => expect(samples[i]).toBeCloseTo(v, 6));
});

test('no sample leaves above the ceiling', () => {
  const samples = frames(200, 0.8);
  limiter().process(samples);
  for (const s of samples) expect(Math.abs(s)).toBeLessThanOrEqual(0.95 + 1e-6);
});

test('one loud channel turns both down alike', () => {
  const samples = new Float32Array([0.9, 0.1]);
  limiter().process(samples);
  expect(samples[1] / samples[0]).toBeCloseTo(0.1 / 0.9, 5);
});

test('the level recovers after a loud passage', () => {
  const l = limiter();
  l.process(frames(50, 0.9));
  const quiet = frames(1000, 0.1);
  l.process(quiet);
  // The last loud frame left the gain at 0.95 / 1.8, and the first quiet one
  // releases it one step.
  const held = 0.95 / 1.8;
  expect(quiet[0]).toBeCloseTo(0.2 * (held + (1 - held) * (1 - Math.exp(-1 / 100))), 5);
  expect(quiet[quiet.length - 1]).toBeCloseTo(0.2, 3);
  for (let i = 1; i < quiet.length; i++) expect(quiet[i]).toBeGreaterThanOrEqual(quiet[i - 1]);
});

test('silence stays silent', () => {
  const samples = new Float32Array(64);
  limiter().process(samples);
  expect([...samples]).toEqual(new Array(64).fill(0));
});

test('limitOutput limits every block the player sends', () => {
  const received: number[][] = [];
  const output = { addSamples: (samples: Float32Array) => void received.push([...samples]) };
  limitOutput(output, limiter());
  output.addSamples(new Float32Array([0.1, 0.1]));
  expect(received).toHaveLength(1);
  received[0].forEach((s) => expect(s).toBeCloseTo(0.2, 6));
});
