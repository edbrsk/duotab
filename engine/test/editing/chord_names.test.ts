import { expect, test } from 'vitest';

import { chordName, chordTones, parseChordName, withAddition } from '../../src/editing/chord_names';
import type { ChordAddition, ChordSpec, ChordType } from '../../src/protocol';

const c = (type: ChordType, additions: ChordAddition[] = [], bass: number | null = null): ChordSpec => ({
  root: 0,
  type,
  additions,
  bass,
});

const types: ChordType[] = ['maj', 'm', '7', 'maj7', 'm7', 'm7b5', 'dim7', 'aug', 'sus2', 'sus4', '6', '5'];
const groups: ChordAddition[][] = [
  ['b9', '9', '#9'],
  ['11', '#11'],
  ['b13', '13'],
];

test('names follow the lead-sheet table', () => {
  expect(chordName(c('7', ['9']))).toBe('C9');
  expect(chordName(c('7', ['9', '13']))).toBe('C13');
  expect(chordName(c('maj7', ['9']))).toBe('Cmaj9');
  expect(chordName(c('m7', ['9']))).toBe('Cm9');
  expect(chordName(c('7', ['13']))).toBe('C7(13)');
  expect(chordName(c('7', ['11']))).toBe('C7(11)');
  expect(chordName(c('m7', ['11']))).toBe('Cm7(11)');
  expect(chordName(c('maj', ['9']))).toBe('Cadd9');
  expect(chordName(c('m', ['9']))).toBe('Cm(add9)');
  expect(chordName(c('6', ['9']))).toBe('C6/9');
  expect(chordName(c('7', ['b9']))).toBe('C7♭9');
  expect(chordName(c('7', ['b9', '#11']))).toBe('C7(♭9♯11)');
  expect(chordName(c('7', ['9', '11']))).toBe('C11');
  expect(chordName(c('7', ['9', '11', '13']))).toBe('C13(11)');
  expect(chordName(c('maj7', [], 4))).toBe('Cmaj7/E');
  expect(chordName({ root: 11, type: '7', additions: ['b9'], bass: null })).toBe('B7♭9');
  expect(chordName(c('m7b5'))).toBe('Cm7♭5');
  expect(chordName(c('maj'))).toBe('C');
});

test('tones follow the tone table', () => {
  expect(chordTones(c('maj7'))).toEqual({ required: [0, 4, 11], optional: [7] });
  expect(chordTones(c('m7b5')).optional).toEqual([6]);
  expect(chordTones(c('5'))).toEqual({ required: [0, 7], optional: [] });
  const sevenThirteen = chordTones(c('7', ['13']));
  expect([...sevenThirteen.required].sort((a, b) => a - b)).toEqual([0, 4, 9, 10]);
  expect(sevenThirteen.optional).toEqual([7]);
});

test('every name reads back as the chord it names', () => {
  const choices = (group: ChordAddition[]) => [null, ...group];
  for (let root = 0; root < 12; root++) {
    for (const type of types) {
      for (const a of choices(groups[0])) {
        for (const b of choices(groups[1])) {
          for (const d of choices(groups[2])) {
            for (const bass of [null, 0, 5, 10]) {
              const additions = [a, b, d].filter((x): x is ChordAddition => x !== null);
              const spec = { root, type, additions, bass };
              const back = parseChordName(chordName(spec));
              expect(back, chordName(spec)).not.toBeNull();
              expect({ ...back!, additions: [...back!.additions].sort() }).toEqual({ ...spec, additions: [...additions].sort() });
            }
          }
        }
      }
    }
  }
});

test('ASCII spellings read too', () => {
  expect(parseChordName('Bb7b9')).toEqual({ root: 10, type: '7', additions: ['b9'], bass: null });
  expect(parseChordName('C#m7')).toEqual({ root: 1, type: 'm7', additions: [], bass: null });
});

test("names DuoScore can't build read as null", () => {
  for (const name of ['N.C.', 'A7sus4', 'C7#5', '']) expect(parseChordName(name), name).toBeNull();
});

test('a clashing addition replaces its partner', () => {
  expect(withAddition(['b9'], '9')).toEqual(['9']);
  expect(withAddition(['b9', '11'], '13')).toEqual(['b9', '11', '13']);
});
