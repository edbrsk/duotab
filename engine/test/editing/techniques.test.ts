import * as alphaTab from '@coderline/alphatab';
import { beforeEach, expect, test } from 'vitest';

import { checkBars } from '../../src/editing/bar_check';
import {
  activeTechniques,
  addGrace,
  dynamicAt,
  setDynamic,
  setTuplet,
  toggleTechnique,
  tupletAt,
} from '../../src/editing/techniques';
import { deleteNote, selectVoice, setDuration, setFret } from '../../src/editing/operations';
import type { EditPosition, TechniqueId } from '../../src/protocol';
import { lineOfEighths, score, twoGuitarsAndDrums } from '../fixtures';

const at = (bar: number, beat: number, string = 1, voice = 0): EditPosition => ({ track: 0, bar, voice, beat, string });
let s: alphaTab.model.Score;
const beat = (bar: number, b: number) => s.tracks[0].staves[0].bars[bar].voices[0].beats[b];
const note = (bar: number, b: number, string: number) => beat(bar, b).notes.find((n) => n.string === string);

const NOTE_TECHNIQUES: TechniqueId[] = [
  'hammerPull',
  'slide',
  'bend',
  'vibrato',
  'palmMute',
  'letRing',
  'deadNote',
  'ghostNote',
  'naturalHarmonic',
  'artificialHarmonic',
  'tie',
  'accent',
  'marcato',
  'tenuto',
  'staccato',
  'doubleFlat',
  'flat',
  'natural',
  'sharp',
  'doubleSharp',
];
const BEAT_TECHNIQUES: TechniqueId[] = ['tapping', 'pickUp', 'pickDown', 'tremolo', 'fermata', 'crescendo', 'diminuendo'];

beforeEach(() => {
  s = score(lineOfEighths);
});

test('each note technique toggles on and off', () => {
  // Beat 1, so a tie has an earlier note to tie from.
  for (const id of NOTE_TECHNIQUES.filter((t) => t !== 'natural')) {
    toggleTechnique(s, at(0, 1, 4), id);
    expect(activeTechniques(s, at(0, 1, 4)), id).toContain(id);
    toggleTechnique(s, at(0, 1, 4), id);
    expect(activeTechniques(s, at(0, 1, 4)), id).not.toContain(id);
  }
});

test('each beat technique toggles on and off', () => {
  for (const id of BEAT_TECHNIQUES) {
    toggleTechnique(s, at(0, 0, 4), id);
    expect(activeTechniques(s, at(0, 0, 4)), id).toContain(id);
    toggleTechnique(s, at(0, 0, 4), id);
    expect(activeTechniques(s, at(0, 0, 4)), id).not.toContain(id);
  }
});

test('natural takes off a forced accidental', () => {
  toggleTechnique(s, at(0, 0, 4), 'sharp');
  toggleTechnique(s, at(0, 0, 4), 'natural');
  expect(activeTechniques(s, at(0, 0, 4))).not.toContain('sharp');
  expect(note(0, 0, 4)!.accidentalMode).toBe(alphaTab.model.NoteAccidentalMode.Default);
});

test('a hammer-on links to the next note on the string', () => {
  toggleTechnique(s, at(0, 0, 4), 'hammerPull');
  expect(note(0, 0, 4)!.hammerPullDestination).toBe(note(0, 1, 4));
});

test('a tie takes the fret of the note it ties from', () => {
  toggleTechnique(s, at(0, 5, 4), 'tie');
  expect(note(0, 5, 4)!.tieOrigin).toBe(note(0, 4, 4));
  expect(note(0, 5, 4)!.fret).toBe(5);
});

test('an exclusive technique replaces the others in its group', () => {
  const only = (first: TechniqueId, second: TechniqueId) => {
    toggleTechnique(s, at(0, 0, 4), first);
    toggleTechnique(s, at(0, 0, 4), second);
    const active = activeTechniques(s, at(0, 0, 4));
    expect(active).toContain(second);
    expect(active).not.toContain(first);
  };
  only('accent', 'marcato');
  only('pickUp', 'pickDown');
  only('sharp', 'flat');
  only('naturalHarmonic', 'artificialHarmonic');
  only('crescendo', 'diminuendo');
});

test('a note technique on an empty string does nothing', () => {
  const before = JSON.stringify(alphaTab.model.JsonConverter.scoreToJsObject(s));
  toggleTechnique(s, at(0, 0, 1), 'palmMute');
  expect(JSON.stringify(alphaTab.model.JsonConverter.scoreToJsObject(s))).toBe(before);
});

test('linking techniques at the end of the song stay harmless', () => {
  for (const id of ['hammerPull', 'slide', 'tie'] as TechniqueId[]) {
    expect(() => toggleTechnique(s, at(1, 3, 1), id)).not.toThrow();
  }
  toggleTechnique(s, at(0, 0, 4), 'tie');
  expect(() => s.finish(new alphaTab.Settings())).not.toThrow();
  expect(note(1, 3, 1)!.fret).toBe(0);
  expect(note(0, 0, 4)!.fret).toBe(5);
});

test('dynamics run forward to the next change', () => {
  const bar0 = () => [0, 1, 2, 3, 4, 5].map((b) => dynamicAt(s, at(0, b)));
  const bar1 = () => [0, 1, 2, 3].map((b) => dynamicAt(s, at(1, b)));
  setDynamic(s, at(0, 2), 'pp');
  expect(bar0()).toEqual(['f', 'f', 'pp', 'pp', 'pp', 'pp']);
  expect(bar1()).toEqual(['pp', 'pp', 'pp', 'pp']);
  setDynamic(s, at(1, 0), 'ff');
  expect(bar1()).toEqual(['ff', 'ff', 'ff', 'ff']);
  expect(bar0()).toEqual(['f', 'f', 'pp', 'pp', 'pp', 'pp']);
});

test('a triplet makes the bar check count three-in-two', () => {
  for (const b of [0, 1, 2]) setTuplet(s, at(0, b), 3);
  expect(tupletAt(s, at(0, 0))).toBe(3);
  expect(checkBars(s, 0)).toEqual([{ bar: 0, voice: 0, ticksOff: -480 }]);
  for (const b of [0, 1, 2]) setTuplet(s, at(0, b), 1);
  expect(tupletAt(s, at(0, 0))).toBe(1);
  expect(checkBars(s, 0)).toEqual([]);
});

test('a grace note does not change the bar check', () => {
  const before = checkBars(s, 0);
  expect(addGrace(s, at(0, 4, 4))).toEqual(at(0, 4, 4));
  expect(beat(0, 4).graceType).toBe(alphaTab.model.GraceType.BeforeBeat);
  expect(beat(0, 4).notes.map((n) => [n.string, n.fret])).toEqual([[4, 5]]);
  expect(beat(0, 5).graceType).toBe(alphaTab.model.GraceType.None);
  expect(beat(0, 5).nextBeat).toBe(beat(0, 6));
  expect(checkBars(s, 0)).toEqual(before);
});

test('every technique survives the .gp round-trip', () => {
  const marks: [EditPosition, TechniqueId[]][] = [
    [at(0, 0, 4), ['hammerPull', 'accent', 'doubleFlat', 'palmMute', 'tapping']],
    [at(0, 1, 4), ['slide', 'marcato', 'flat', 'letRing', 'pickUp']],
    [at(0, 2, 4), ['bend', 'tenuto', 'natural', 'vibrato', 'pickDown']],
    [at(0, 3, 4), ['naturalHarmonic', 'staccato', 'sharp', 'tremolo']],
    [at(0, 4, 4), ['artificialHarmonic', 'doubleSharp', 'ghostNote', 'fermata']],
    [at(0, 5, 4), ['crescendo']],
    [at(1, 0, 1), ['deadNote', 'diminuendo']],
    [at(1, 2, 1), ['tie']],
  ];
  for (const [position, ids] of marks) for (const id of ids) toggleTechnique(s, position, id);
  expect(new Set(marks.flatMap(([, ids]) => ids))).toEqual(new Set([...NOTE_TECHNIQUES, ...BEAT_TECHNIQUES]));
  setDynamic(s, at(1, 1), 'pp');
  for (const b of [0, 1, 2]) setTuplet(s, at(0, b), 3);
  addGrace(s, at(1, 3, 1));

  const read = (song: alphaTab.model.Score) =>
    song.tracks[0].staves[0].bars.flatMap((bar) =>
      bar.voices[0].beats.flatMap((b) =>
        [1, 2, 3, 4, 5, 6].map((string) => {
          const position = at(bar.index, b.index, string);
          return [activeTechniques(song, position), dynamicAt(song, position), tupletAt(song, position), b.graceType];
        }),
      ),
    );
  const settings = new alphaTab.Settings();
  const bytes = new alphaTab.exporter.Gp7Exporter().export(s, settings);
  const reloaded = alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, settings);
  expect(read(reloaded)).toEqual(read(s));
});

const fermataBeats = (song: alphaTab.model.Score, bar: number, voice = 0) =>
  song.tracks[0].staves[0].bars[bar].voices[voice].beats.filter((b) => b.fermata !== null).map((b) => b.index);

test('a fermata comes off when another track has a beat at the same time', () => {
  s = score(twoGuitarsAndDrums);
  toggleTechnique(s, at(0, 0), 'fermata');
  toggleTechnique(s, at(0, 0), 'fermata');
  s.finish(new alphaTab.Settings());
  expect(activeTechniques(s, at(0, 0))).not.toContain('fermata');
  expect(s.masterBars[0].fermata?.size ?? 0).toBe(0);
});

test('a fermata comes off when another voice has a beat at the same time', () => {
  selectVoice(s, at(0, 0), 1);
  toggleTechnique(s, at(0, 0), 'fermata');
  toggleTechnique(s, at(0, 0), 'fermata');
  s.finish(new alphaTab.Settings());
  expect(fermataBeats(s, 0)).toEqual([]);
});

test('a fermata stays on its beat when an earlier beat changes length', () => {
  toggleTechnique(s, at(0, 3, 4), 'fermata');
  setDuration(s, at(0, 0), alphaTab.model.Duration.Quarter, 0);
  expect(fermataBeats(s, 0)).toEqual([3]);
  expect([...s.masterBars[0].fermata!.keys()]).toEqual([1920]);
});

test('editing another voice keeps the fermatas of the first', () => {
  toggleTechnique(s, at(0, 2, 4), 'fermata');
  selectVoice(s, at(0, 0), 1);
  setFret(s, at(0, 0, 1, 1), 3);
  expect(fermataBeats(s, 0)).toEqual([2]);
});

test('a tie whose origin is deleted ties to the note before it, as the copy does', () => {
  toggleTechnique(s, at(0, 5, 4), 'tie');
  deleteNote(s, at(0, 4, 4));
  expect(note(0, 5, 4)!.tieOrigin).toBe(note(0, 3, 4));
  expect(note(0, 5, 4)!.fret).toBe(7);
});

test('a slide and a hammer-on link to a note entered between', () => {
  toggleTechnique(s, at(0, 0, 4), 'slide');
  toggleTechnique(s, at(0, 2, 4), 'hammerPull');
  deleteNote(s, at(0, 1, 4));
  deleteNote(s, at(0, 3, 4));
  expect(note(0, 0, 4)!.slideTarget).toBe(note(0, 2, 4));
  expect(note(0, 2, 4)!.hammerPullDestination).toBe(note(0, 4, 4));
  setFret(s, at(0, 1, 4), 6);
  setFret(s, at(0, 3, 4), 6);
  expect(note(0, 0, 4)!.slideTarget).toBe(note(0, 1, 4));
  expect(note(0, 2, 4)!.slideOrigin).toBeNull();
  expect(note(0, 2, 4)!.hammerPullDestination).toBe(note(0, 3, 4));
  expect(note(0, 4, 4)!.hammerPullOrigin).toBeNull();
});

test('a natural harmonic follows a new fret', () => {
  toggleTechnique(s, at(0, 0, 4), 'naturalHarmonic');
  setFret(s, at(0, 0, 4), 12);
  expect(note(0, 0, 4)!.harmonicValue).toBe(12);
});

test('typing a fret on a tied note takes off the tie', () => {
  toggleTechnique(s, at(0, 5, 4), 'tie');
  setFret(s, at(0, 5, 4), 3);
  expect(note(0, 5, 4)!.fret).toBe(3);
  expect(activeTechniques(s, at(0, 5, 4))).not.toContain('tie');
});
