import * as alphaTab from '@coderline/alphatab';

import type { NewSongOptions } from '../protocol';
import { restsFilling } from './operations';

const BARS = 4;
const CLEAN = 27;

export function newSong(options: NewSongOptions, settings = new alphaTab.Settings()): alphaTab.model.Score {
  const tuning = options.tuning.map((note) => alphaTab.model.Tuning.getTextForTuning(note, true)).join(' ');
  const ticks = (3840 * options.numerator) / options.denominator;
  const rests = restsFilling(ticks)
    .map((r) => `r.${r.duration}${r.dots ? '{d}' : ''}`)
    .join(' ');
  const importer = new alphaTab.importer.AlphaTexImporter();
  importer.initFromString(
    String.raw`\tempo ${options.tempo}
.
\track "Guitar" \instrument ${CLEAN} \tuning ${tuning}
\ts ${options.numerator} ${options.denominator} ${Array(BARS).fill(rests).join(' | ')}`,
    settings,
  );
  const score = importer.readScore();
  // Set on the model, so no character of the title can break the alphaTex.
  score.title = options.title;
  return score;
}
