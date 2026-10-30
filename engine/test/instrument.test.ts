import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { applyProgram } from '../src/instrument';
import { score } from './fixtures';

const withInstrumentChanges = String.raw`\track "G" \instrument 29 \tuning E4 B3 G3 D3 A2 E2
0.6.4{instrument 29} 0.6.4 0.6.2 | 0.6.1{instrument 30}`;

const programsPlayed = (song: alphaTab.model.Score) => {
  const midi = new alphaTab.midi.MidiFile();
  new alphaTab.midi.MidiFileGenerator(song, new alphaTab.Settings(), new alphaTab.midi.AlphaSynthMidiFileHandler(midi)).generate();
  const channel = song.tracks[0].playbackInfo.primaryChannel;
  return midi.events
    .filter((e) => e.type === alphaTab.midi.MidiEventType.ProgramChange && (e as alphaTab.midi.ProgramChangeEvent).channel === channel)
    .map((e) => (e as alphaTab.midi.ProgramChangeEvent).program);
};

test('a tone replaces the instrument changes the file plays', () => {
  const song = score(withInstrumentChanges);
  expect(programsPlayed(song)).toContain(30);
  expect(applyProgram(song.tracks[0], 27)).toBe(true);
  expect(new Set(programsPlayed(song))).toEqual(new Set([27]));
});

test('the same tone changes nothing', () => {
  const song = score(withInstrumentChanges);
  applyProgram(song.tracks[0], 27);
  expect(applyProgram(song.tracks[0], 27)).toBe(false);
});
