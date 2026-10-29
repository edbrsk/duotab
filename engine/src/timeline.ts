import * as alphaTab from '@coderline/alphatab';

import type { BarInfo } from './protocol';

const TICKS_PER_QUARTER = 960;

/** Each bar's first pass in playback order, so repeats count. */
export function barTimeline(score: alphaTab.model.Score): BarInfo[] {
  const generator = new alphaTab.midi.MidiFileGenerator(
    score,
    new alphaTab.Settings(),
    new alphaTab.midi.AlphaSynthMidiFileHandler(new alphaTab.midi.MidiFile()),
  );
  generator.generate();

  let tempo = score.tempo;
  let tick = 0;
  let ms = 0;
  const advance = (to: number) => {
    ms += ((to - tick) / TICKS_PER_QUARTER) * (60000 / tempo);
    tick = to;
  };
  const firstPass = new Map<number, { startTick: number; startMs: number; tempo: number }>();
  for (const lookup of generator.tickLookup.masterBars) {
    advance(lookup.start);
    const changes = [...lookup.tempoChanges].sort((a, b) => a.tick - b.tick);
    for (const change of changes) if (change.tick <= lookup.start) tempo = change.tempo;
    if (!firstPass.has(lookup.masterBar.index)) {
      firstPass.set(lookup.masterBar.index, { startTick: lookup.start, startMs: Math.round(ms), tempo });
    }
    for (const change of changes) {
      if (change.tick > lookup.start) {
        advance(change.tick);
        tempo = change.tempo;
      }
    }
  }

  const bars: BarInfo[] = [];
  for (const masterBar of score.masterBars) {
    const previous = bars.at(-1);
    // A bar the MIDI never reaches keeps its written position.
    const pass = firstPass.get(masterBar.index) ?? {
      startTick: masterBar.start,
      startMs: previous?.startMs ?? 0,
      tempo: previous?.tempo ?? score.tempo,
    };
    bars.push({
      index: masterBar.index,
      ...pass,
      section: masterBar.section ? { marker: masterBar.section.marker, text: masterBar.section.text } : null,
    });
  }
  return bars;
}

export function barsWithNotes(track: alphaTab.model.Track): boolean[] {
  return track.staves[0].bars.map((bar) => !bar.isRestOnly);
}

export function barAtTick(
  lookups: readonly { start: number; end: number; masterBar: { index: number } }[],
  tick: number,
): number {
  let bar = lookups[0]?.masterBar.index ?? 0;
  for (const lookup of lookups) {
    if (lookup.start > tick) break;
    bar = lookup.masterBar.index;
  }
  return bar;
}
