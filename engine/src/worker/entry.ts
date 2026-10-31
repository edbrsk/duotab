// DuoScore's alphaTab.worker.mjs: alphaTab's own entry, with the synth hooks first.
import * as alphaTab from '@coderline/alphatab';

import { installSynthHooks, type PanMessage } from './synth_hooks';

const hooks = installSynthHooks(alphaTab, (frame) => postMessage(frame));
addEventListener('message', (e: MessageEvent<PanMessage>) => {
  if (e.data?.cmd === 'duoscore.pan') hooks.setPan(e.data.channel, e.data.shift);
});
alphaTab.Environment.initializeWorker();
