import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { movesTicks, runCommand } from '../../src/editing/commands';
import { History } from '../../src/editing/history';
import type { EditCommand, EditPosition } from '../../src/protocol';
import { fourQuarters, guitarsAndDrums, lineOfEighths, score, sixBars, twoTracksThreeBars } from '../fixtures';

const start: EditPosition = { track: 0, bar: 0, voice: 0, beat: 0, string: 1 };

test('an edit records history and reports the change', () => {
  const s = score(fourQuarters);
  const history = new History();
  const result = runCommand(s, start, { op: 'setFret', fret: 9 }, history);
  expect(result.edited).toBe(true);
  expect(history.canUndo).toBe(true);
  expect(s.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0].fret).toBe(9);
});

test('moving the cursor is not an edit', () => {
  const history = new History();
  const result = runCommand(score(fourQuarters), start, { op: 'move', direction: 'right' }, history);
  expect(result).toEqual({ position: { ...start, beat: 1 }, edited: false, marks: [] });
  expect(history.canUndo).toBe(false);
});

test('moving right into a new bar is an edit', () => {
  const s = score(fourQuarters);
  const history = new History();
  const result = runCommand(s, { ...start, bar: 1 }, { op: 'move', direction: 'right' }, history);
  expect(result.edited).toBe(true);
  expect(history.canUndo).toBe(true);
  expect(s.masterBars).toHaveLength(3);
});

test('place clamps the position to the song', () => {
  const result = runCommand(
    score(fourQuarters),
    start,
    { op: 'place', position: { track: 0, bar: 9, voice: 3, beat: 9, string: 9 } },
    new History(),
  );
  expect(result.position).toEqual({ track: 0, bar: 1, voice: 0, beat: 0, string: 6 });
});

test('a failed edit leaves no history step', () => {
  const history = new History();
  expect(() => runCommand(score(fourQuarters), start, { op: 'setFret', fret: 30 }, history)).toThrow();
  expect(history.canUndo).toBe(false);
});

test('a command that changes nothing is not an edit', () => {
  const s = score(fourQuarters);
  const history = new History();
  const rest = { ...start, beat: 3, string: 2 };
  const fullBarRest = { ...start, bar: 1 };
  for (const [at, command] of [
    [{ ...start, string: 4 }, { op: 'deleteNote' }],
    [fullBarRest, { op: 'deleteNote' }],
    [rest, { op: 'setRest' }],
    [start, { op: 'setFret', fret: 0 }],
    [start, { op: 'setDuration', duration: 4, dots: 0 }],
    [start, { op: 'selectVoice', voice: 0 }],
  ] as const) {
    expect(runCommand(s, at, command, history).edited, command.op).toBe(false);
  }
  expect(history.canUndo).toBe(false);
});

test('a note technique on an empty string is not an edit', () => {
  const history = new History();
  const result = runCommand(score(lineOfEighths), start, { op: 'toggle', technique: 'palmMute' }, history);
  expect(result.edited).toBe(false);
  expect(history.canUndo).toBe(false);
});

test('a technique toggle is an edit and can be undone', async () => {
  const s = score(lineOfEighths);
  const history = new History();
  const at = { ...start, string: 4 };
  for (const command of [
    { op: 'toggle', technique: 'palmMute' },
    { op: 'setDynamic', dynamic: 'pp' },
    { op: 'setTuplet', tuplet: 3 },
    { op: 'addGrace' },
  ] as const) {
    expect(runCommand(s, at, command, history).edited, command.op).toBe(true);
  }
  let undone = s;
  for (let i = 0; i < 4; i++) undone = (await history.undo(undone))!;
  expect(undone.tracks[0].staves[0].bars[0].voices[0].beats[0].notes[0].isPalmMute).toBe(false);
});

test('a new title is an edit and can be undone', async () => {
  const s = score(fourQuarters);
  const history = new History();
  expect(runCommand(s, start, { op: 'setTitle', title: '  Riff  ' }, history).edited).toBe(true);
  expect(s.title).toBe('Riff');
  expect((await history.undo(s))!.title).toBe('Edit');
});

test('the same title is not an edit', () => {
  const s = score(fourQuarters);
  const history = new History();
  expect(runCommand(s, start, { op: 'setTitle', title: 'Edit' }, history).edited).toBe(false);
  expect(history.canUndo).toBe(false);
});

test('a new artist is an edit and can be undone', async () => {
  const s = score(fourQuarters);
  const history = new History();
  expect(runCommand(s, start, { op: 'setArtist', artist: '  Rabea  ' }, history).edited).toBe(true);
  expect(s.artist).toBe('Rabea');
  expect(runCommand(s, start, { op: 'setArtist', artist: 'Rabea' }, history).edited).toBe(false);
  expect(runCommand(s, start, { op: 'setArtist', artist: '' }, history).edited).toBe(true);
  expect(s.artist).toBe('');
  expect((await history.undo(s))!.artist).toBe('Rabea');
});

test('Guitar Pro keeps the artist', () => {
  const s = score(fourQuarters);
  runCommand(s, start, { op: 'setArtist', artist: 'Rabea Massaad' }, new History());
  const bytes = new alphaTab.exporter.Gp7Exporter().export(s, new alphaTab.Settings());
  expect(alphaTab.importer.ScoreLoader.loadScoreFromBytes(bytes, new alphaTab.Settings()).artist).toBe('Rabea Massaad');
});

test('bar commands are edits and undo', async () => {
  for (const command of [
    { op: 'setTimeSignature', numerator: 3, denominator: 4 },
    { op: 'setTempo', bpm: 140 },
    { op: 'setKeySignature', key: 2, minor: false },
    { op: 'setClef', clef: 'bass' },
    { op: 'insertBar' },
    { op: 'deleteBar' },
  ] as const) {
    const s = score(twoTracksThreeBars);
    const before = alphaTab.model.JsonConverter.scoreToJson(s);
    const history = new History();
    expect(runCommand(s, { ...start, bar: 1 }, command, history).edited, command.op).toBe(true);
    const undone = (await history.undo(s))!;
    expect(alphaTab.model.JsonConverter.scoreToJson(undone), command.op).toBe(before);
  }
});

test('undo brings back a deleted bar', async () => {
  const s = score(twoTracksThreeBars);
  const history = new History();
  runCommand(s, start, { op: 'deleteBar' }, history);
  expect(s.masterBars).toHaveLength(2);
  const undone = (await history.undo(s))!;
  expect(undone.masterBars).toHaveLength(3);
  expect(undone.tracks[0].staves[0].bars[0].voices[0].beats[1].notes[0].fret).toBe(2);
});

test('setting the same time signature is not an edit', () => {
  const s = score(twoTracksThreeBars);
  const history = new History();
  expect(runCommand(s, start, { op: 'setTimeSignature', numerator: 4, denominator: 4 }, history).edited).toBe(false);
  expect(history.canUndo).toBe(false);
});

test('bar edits that move ticks clear the loop', () => {
  const moving = ['insertBar', 'deleteBar', 'setTimeSignature', 'pasteBars'];
  for (const op of ['setFret', 'setTempo', 'setKeySignature', 'setClef', 'copyBars', ...moving]) {
    expect(movesTicks({ op } as never), op).toBe(moving.includes(op));
  }
});

const structureCommands: EditCommand[] = [
  { op: 'toggleRepeatStart' },
  { op: 'setRepeatEnd', count: 3 },
  { op: 'toggleEnding', ending: 2 },
  { op: 'toggleDirection', direction: 'segno' },
];

test('structure commands are edits and undo', async () => {
  for (const command of structureCommands) {
    const s = score(sixBars);
    const before = alphaTab.model.JsonConverter.scoreToJson(s);
    const history = new History();
    expect(runCommand(s, { ...start, bar: 2 }, command, history).edited, command.op).toBe(true);
    expect(alphaTab.model.JsonConverter.scoreToJson((await history.undo(s))!), command.op).toBe(before);
  }
});

test('structure commands move ticks', () => {
  for (const command of structureCommands) expect(movesTicks(command), command.op).toBe(true);
});

test('a track edit is an edit and undoes', async () => {
  for (const command of [
    { op: 'addTrack', tuning: [64, 59, 55, 50, 45, 40], program: 27 },
    { op: 'removeTrack', track: 1 },
    { op: 'moveTrack', track: 1, to: 0 },
    { op: 'renameTrack', track: 0, name: 'Lead' },
  ] satisfies EditCommand[]) {
    const s = score(guitarsAndDrums);
    const before = alphaTab.model.JsonConverter.scoreToJson(s);
    const history = new History();
    expect(runCommand(s, start, command, history).edited, command.op).toBe(true);
    expect(alphaTab.model.JsonConverter.scoreToJson((await history.undo(s))!), command.op).toBe(before);
  }
});

test('every model change the palette can make is an edit', () => {
  const settings = new alphaTab.Settings();
  const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 1 };

  const common = score(String.raw`\track "G" \tuning E4 B3 G3 D3 A2 E2
\ts common 0.6.1 | 0.6.1`);
  const history = new History();
  expect(runCommand(common, at, { op: 'setTimeSignature', numerator: 3, denominator: 4 }, history, settings).edited).toBe(true);
  expect(history.canUndo).toBe(true);

  const natural = score(String.raw`\track "G" \tuning E4 B3 G3 D3 A2 E2
0.6{acc forceNatural}.1`);
  expect(runCommand(natural, at, { op: 'toggle', technique: 'natural' }, new History(), settings).edited).toBe(true);

  const unplayable = score(String.raw`\track "G" \tuning E4 B3 G3 D3 A2 E2
\chord "Hi" 5 x x x x x
5.1{ch "Hi"}.1`);
  const before = unplayable.tracks[0].staves[0].chords!.get('hi00')!.showDiagram;
  const retuned = runCommand(unplayable, at, { op: 'retune', track: 0, tuning: [64, 59, 55, 50, 45, 40], octave: 2 }, new History(), settings);
  expect(before).toBe(true);
  expect(unplayable.tracks[0].staves[0].chords!.get('hi00')!.showDiagram).toBe(false);
  expect(retuned.edited).toBe(true);
});

test('4/4 on a common-time bar that already reads 4/4 changes nothing', () => {
  const common = score(String.raw`\track "G" \tuning E4 B3 G3 D3 A2 E2
\ts common 0.6.1`);
  const at = { track: 0, bar: 0, voice: 0, beat: 0, string: 1 };
  expect(runCommand(common, at, { op: 'setTimeSignature', numerator: 4, denominator: 4 }, new History()).edited).toBe(false);
  expect(common.masterBars[0].timeSignatureCommon).toBe(true);
});
