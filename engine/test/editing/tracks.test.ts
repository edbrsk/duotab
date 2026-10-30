import * as alphaTab from '@coderline/alphatab';
import { beforeEach, expect, test } from 'vitest';

import { EditSession } from '../../src/editing/session';
import { addTrack, moveTrack, removeTrack, renameTrack } from '../../src/editing/tracks';
import { guitarsAndDrums, score } from '../fixtures';

const DROP_D = [64, 59, 55, 50, 45, 38];
let s: alphaTab.model.Score;
const names = () => s.tracks.map((t) => t.name);

beforeEach(() => {
  s = score(guitarsAndDrums);
});

test('the fixture has its form', () => {
  expect(s.masterBars.map((m) => m.calculateDuration())).toEqual([3840, 2880, 3840]);
  expect(s.masterBars[2].isRepeatStart && s.masterBars[2].repeatCount).toBe(2);
});

test('an added track fits every bar', () => {
  expect(addTrack(s, { tuning: DROP_D, program: 27 })).toBe(3);
  const track = s.tracks[3];
  const staff = track.staves[0];
  expect(track.name).toBe('Guitar 1');
  expect(staff.bars.map((b) => b.voices[0].beats.reduce((t, x) => t + x.playbackDuration, 0))).toEqual([3840, 2880, 3840]);
  expect(staff.bars.every((b) => b.voices[0].beats.every((x) => x.isRest))).toBe(true);
  expect(staff.tuning).toEqual(DROP_D);
  expect([staff.showStandardNotation, staff.showTablature, staff.displayTranspositionPitch]).toEqual([true, true, -12]);
  expect([track.playbackInfo.volume, track.playbackInfo.program]).toEqual([12, 27]);
  const others = s.tracks.slice(0, 3).flatMap((t) => [t.playbackInfo.primaryChannel, t.playbackInfo.secondaryChannel]);
  for (const channel of [track.playbackInfo.primaryChannel, track.playbackInfo.secondaryChannel]) {
    expect(others).not.toContain(channel);
    expect(channel).not.toBe(9);
  }
});

test('added tracks take free names and channels', () => {
  addTrack(s, { tuning: DROP_D, program: 27 });
  addTrack(s, { tuning: DROP_D, program: 27 });
  expect(names().slice(3)).toEqual(['Guitar 1', 'Guitar 2']);
  expect(s.tracks[4].playbackInfo.primaryChannel).not.toBe(s.tracks[3].playbackInfo.primaryChannel);
  expect(s.tracks[4].playbackInfo.primaryChannel).not.toBe(s.tracks[3].playbackInfo.secondaryChannel);
});

test('removing a track removes its notes and keeps the others', () => {
  const before = s.tracks[0].staves[0].bars.map((b) => b.voices[0].beats.map((x) => x.notes.map((n) => n.fret)));
  removeTrack(s, 1);
  expect(names()).toEqual(['Guitar A', 'Drums']);
  expect(s.tracks.map((t) => t.index)).toEqual([0, 1]);
  expect(s.tracks[0].staves[0].bars.map((b) => b.voices[0].beats.map((x) => x.notes.map((n) => n.fret)))).toEqual(before);
});

test('the song keeps a guitar track', () => {
  removeTrack(s, 0);
  expect(() => removeTrack(s, 0)).toThrow('the song keeps one guitar track');
  expect(() => removeTrack(s, 1)).toThrow('only guitar tracks can be removed');
});

test('moving a track reorders and reindexes', () => {
  moveTrack(s, 1, 0);
  expect(names()).toEqual(['Guitar B', 'Guitar A', 'Drums']);
  expect(s.tracks.map((t) => t.index)).toEqual([0, 1, 2]);
});

test('renaming trims and refuses an empty name', () => {
  renameTrack(s, 0, '  Lead  ');
  expect(s.tracks[0].name).toBe('Lead');
  expect(() => renameTrack(s, 0, '   ')).toThrow('a track needs a name');
});

test('track edits survive the .gp round-trip', () => {
  addTrack(s, { tuning: DROP_D, program: 27 });
  moveTrack(s, 3, 1);
  renameTrack(s, 1, 'Drop D');
  const settings = new alphaTab.Settings();
  const reloaded = alphaTab.importer.ScoreLoader.loadScoreFromBytes(
    new alphaTab.exporter.Gp7Exporter().export(s, settings),
    settings,
  );
  const read = (song: alphaTab.model.Score) =>
    song.tracks.map((t) => [t.name, t.staves[0].isPercussion ? null : [...t.staves[0].tuning]]);
  expect(read(reloaded)).toEqual(read(s));
});

test('removing the drawn track draws the nearest guitar track', () => {
  const session = new EditSession();
  session.open(s, 1);
  session.command(s, { op: 'removeTrack', track: 1 });
  expect(session.track).toBe(0);
  s = score(guitarsAndDrums);
  session.open(s, 0);
  session.command(s, { op: 'place', position: { track: 0, bar: 0, voice: 0, beat: 0, string: 1 } });
  session.command(s, { op: 'removeTrack', track: 1 });
  expect(session.track).toBe(0);
  expect(session.position).not.toBeNull();
  session.command(s, { op: 'moveTrack', track: 0, to: 1 });
  expect(session.track).toBe(1);
  expect(session.position?.track).toBe(1);
});

test('removing or moving a track keeps its display flags with it', () => {
  s = score(guitarsAndDrums);
  s.stylesheet.perTrackMultiBarRest = new Set([1]);
  s.stylesheet.perTrackDisplayTuning = new Map([[1, false]]);
  moveTrack(s, 1, 0);
  expect([...s.stylesheet.perTrackMultiBarRest!]).toEqual([0]);
  expect([...s.stylesheet.perTrackDisplayTuning!]).toEqual([[0, false]]);
  removeTrack(s, 0);
  expect(s.stylesheet.perTrackMultiBarRest!.size).toBe(0);
  expect(s.stylesheet.perTrackDisplayTuning!.size).toBe(0);
});

test('a rename renames a derived short name too', () => {
  s = score(guitarsAndDrums);
  renameTrack(s, 0, 'Rhythm guitar');
  expect(s.tracks[0].shortName).toBe('Rhythm gui');

  const custom = score(String.raw`\track "Guitar A" "Lead" \tuning E4 B3 G3 D3 A2 E2
0.6.1`);
  renameTrack(custom, 0, 'Rhythm');
  expect(custom.tracks[0].shortName).toBe('Lead');

  const prefix = score(String.raw`\track "Guitar A" "Gui" \tuning E4 B3 G3 D3 A2 E2
0.6.1`);
  renameTrack(prefix, 0, 'Bass line');
  expect(prefix.tracks[0].shortName).toBe('Bass line');
});

test('move and rename refuse other tracks and indexes past the end', () => {
  s = score(guitarsAndDrums);
  expect(() => renameTrack(s, 9, 'X')).toThrow('no track 9');
  expect(() => renameTrack(s, 2, 'X')).toThrow('only guitar tracks can be renamed');
  expect(() => moveTrack(s, 2, 0)).toThrow('only guitar tracks can be moved');
});
