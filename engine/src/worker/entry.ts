// DuoScore's alphaTab.worker.mjs: alphaTab's own entry, with the synth hooks first.
import * as alphaTab from '@coderline/alphatab';

import { installSynthHooks, type MeteringMessage, type PanMessage } from './synth_hooks';

const hooks = installSynthHooks(alphaTab, (frame) => postMessage(frame));
addEventListener('message', (e: MessageEvent<PanMessage | MeteringMessage>) => {
  if (e.data?.cmd === 'duoscore.pan') hooks.setPan(e.data.channel, e.data.shift);
  if (e.data?.cmd === 'duoscore.metering') hooks.setMetering(e.data.on);
});
alphaTab.Environment.initializeWorker();
