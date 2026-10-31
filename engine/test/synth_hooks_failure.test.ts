import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { installSynthHooks } from '../src/worker/synth_hooks';

installSynthHooks(alphaTab, () => {
  throw new Error('no page');
});

test("a failing level post doesn't stop the player", () => {
  const player = {
    state: alphaTab.synth.PlayerState.Playing,
    sequencer: { isFinished: true, currentTime: 0 },
    synthesizer: { activeVoiceCount: 0 },
    output: { addSamples() {} },
  };
  const onSampleRequest = (alphaTab.synth.AlphaSynthBase.prototype as unknown as { onSampleRequest(): void }).onSampleRequest;
  expect(() => onSampleRequest.call(player)).not.toThrow();
});
