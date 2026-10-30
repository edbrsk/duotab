import * as alphaTab from '@coderline/alphatab';

type Automation = { type: alphaTab.model.AutomationType; value: number };

/** A track as the mixer and undo see it; staves are absent in mixer tests. */
export type ProgramTrack = {
  playbackInfo: { program: number };
  staves?: { bars: { voices: { beats: { automations: Automation[] }[] }[] }[] }[];
};

/**
 * Plays the whole track with `program`. Guitar Pro files store instrument
 * changes on beats, which the MIDI plays over the track's own program, so
 * they take the program too. Returns whether anything changed.
 */
export function applyProgram(track: ProgramTrack, program: number): boolean {
  let changed = track.playbackInfo.program !== program;
  track.playbackInfo.program = program;
  for (const staff of track.staves ?? []) {
    for (const bar of staff.bars) {
      for (const voice of bar.voices) {
        for (const beat of voice.beats) {
          for (const automation of beat.automations) {
            if (automation.type === alphaTab.model.AutomationType.Instrument && automation.value !== program) {
              automation.value = program;
              changed = true;
            }
          }
        }
      }
    }
  }
  return changed;
}
