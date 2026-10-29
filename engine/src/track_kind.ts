import type { TrackKind } from './protocol';

// 0-based General MIDI programs 24–31 are the guitar family.
const guitarPrograms = { first: 24, last: 31 };

export function classifyTrack(t: {
  isPercussion: boolean;
  stringCount: number;
  midiProgram: number;
}): TrackKind {
  if (t.isPercussion) return 'drums';
  if (t.stringCount > 0) return 'guitar';
  if (t.midiProgram >= guitarPrograms.first && t.midiProgram <= guitarPrograms.last) return 'guitar';
  return 'other';
}
