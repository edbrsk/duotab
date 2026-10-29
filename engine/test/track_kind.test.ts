import { expect, test } from 'vitest';

import { classifyTrack } from '../src/track_kind';

test('classifies tracks', () => {
  expect(classifyTrack({ isPercussion: true, stringCount: 6, midiProgram: 0 })).toBe('drums');
  expect(classifyTrack({ isPercussion: false, stringCount: 7, midiProgram: 0 })).toBe('guitar');
  expect(classifyTrack({ isPercussion: false, stringCount: 0, midiProgram: 29 })).toBe('guitar');
  expect(classifyTrack({ isPercussion: false, stringCount: 0, midiProgram: 33 })).toBe('other');
});
