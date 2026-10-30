import { expect, test } from 'vitest';

import { drawAfterTrackEdit } from '../../src/editing/track_render';

function fakes() {
  const calls: string[] = [];
  const tracks = ['a', 'b'];
  const api = {
    score: { tracks },
    renderTracks: (drawn: unknown[]) => calls.push(`render ${drawn.join()}`),
    loadMidiForScore: () => calls.push('loadMidi'),
  };
  const mixer = {
    async regenerate(load: () => void) {
      calls.push('regenerate');
      load();
    },
  };
  return { api, mixer, calls };
}

test('a track edit draws the drawn track and loads new MIDI', async () => {
  for (const op of ['addTrack', 'removeTrack', 'moveTrack'] as const) {
    const { api, mixer, calls } = fakes();
    await drawAfterTrackEdit(api, mixer, 1, op);
    // alphaTab loads no MIDI when given the score it already has.
    expect(calls, op).toEqual(['regenerate', 'render b', 'loadMidi']);
  }
});

test('a rename only redraws', async () => {
  const { api, mixer, calls } = fakes();
  await drawAfterTrackEdit(api, mixer, 0, 'renameTrack');
  expect(calls).toEqual(['render a']);
});
