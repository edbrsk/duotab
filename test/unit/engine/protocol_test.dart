import 'package:duoscore/engine/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a song summary', () {
    final song = SongSummary.fromJson({
      'title': 'Fixture',
      'tracks': [
        {
          'index': 0,
          'name': 'Guitar 1',
          'kind': 'guitar',
          'stringCount': 6,
          'tuning': [64, 59, 55, 50, 45, 40],
          'midiProgram': 29,
          'volume': 9,
          'volumeDb': -6.0,
          'pan': -1,
          'channel': 4,
        },
        {
          'index': 1,
          'name': 'Drums',
          'kind': 'drums',
          'stringCount': null,
          'tuning': null,
          'midiProgram': 0,
        },
        {
          'index': 2,
          'name': 'Keys',
          'kind': 'other',
          'stringCount': null,
          'tuning': null,
          'midiProgram': 4,
        },
      ],
    });

    expect(song.title, 'Fixture');
    expect(song.tracks.map((t) => t.kind), [
      TrackKind.guitar,
      TrackKind.drums,
      TrackKind.other,
    ]);
    expect(song.tracks.first.tuning, [64, 59, 55, 50, 45, 40]);
    expect([song.tracks.first.volume, song.tracks.first.channel], [9, 4]);
    expect([song.tracks.first.volumeDb, song.tracks.first.pan], [-6.0, -1.0]);
    expect(song.tracks[1].volumeDb, 0);
    expect(song.masterDb, 0);
    expect(song.tracks[1].stringCount, isNull);
    expect(song.guitarTracks.map((t) => t.name), ['Guitar 1']);
  });

  test('parses bars and bars with notes', () {
    final song = SongSummary.fromJson({
      'title': 'T',
      'bars': [
        {
          'index': 0,
          'startTick': 0,
          'startMs': 0,
          'tempo': 120,
          'section': {'marker': 'A', 'text': 'Intro'},
        },
      ],
      'tracks': [
        {
          'index': 0,
          'name': 'G',
          'kind': 'guitar',
          'stringCount': 6,
          'tuning': [64, 59, 55, 50, 45, 40],
          'midiProgram': 29,
          'barsWithNotes': [true],
        },
      ],
    });

    expect(song.bars.single.section!.marker, 'A');
    expect(song.bars.single.tempo, 120);
    expect(song.tracks.single.barsWithNotes, [true]);
  });

  test('a summary without bars parses to empty lists', () {
    final song = SongSummary.fromJson({
      'title': 'T',
      'tracks': [
        {
          'index': 0,
          'name': 'G',
          'kind': 'guitar',
          'stringCount': 6,
          'tuning': [64, 59, 55, 50, 45, 40],
          'midiProgram': 29,
        },
      ],
    });

    expect(song.bars, isEmpty);
    expect(song.tracks.single.barsWithNotes, isEmpty);
    expect(song.artist, '');
  });

  test("a summary reads the song's artist", () {
    final song = SongSummary.fromJson({
      'title': 'T',
      'artist': 'Rabea Massaad',
      'tracks': const [],
    });
    expect(song.artist, 'Rabea Massaad');
  });

  test('SetArtist sends the artist', () {
    expect(const SetArtist('A').toJson(), {'op': 'setArtist', 'artist': 'A'});
  });

  test('a staff view sends all four views', () {
    expect(
      const StaffView(
        index: 1,
        notation: true,
        tab: false,
        slash: true,
      ).toJson(),
      {
        'index': 1,
        'notation': true,
        'tab': false,
        'slash': true,
        'numbered': false,
      },
    );
  });

  test('retune serialises its track, tuning and octave', () {
    expect(const RetuneTrack(1, [64, 59, 55, 50, 45, 40], -1).toJson(), {
      'op': 'retune',
      'track': 1,
      'tuning': [64, 59, 55, 50, 45, 40],
      'octave': -1,
      'keep': 'pitch',
    });
    expect(
      const RetuneTrack(
        1,
        [64, 59, 55, 50, 45, 40],
        0,
        keepFrets: true,
      ).toJson()['keep'],
      'frets',
    );
  });

  test('the edit state reads the retune report', () {
    final state = EditState.fromJson({
      'position': null,
      'issues': <Object>[],
      'canUndo': true,
      'canRedo': false,
      'song': {'title': 'T', 'tracks': <Object>[], 'unplayableNotes': 3},
      'edited': true,
      'retune': {
        'track': 0,
        'tuning': [64, 59, 55, 50, 45, 40],
        'octave': 1,
        'keep': 'frets',
        'moved': 12,
        'unplayable': 3,
      },
    });
    expect(state.retune!.track, 0);
    expect(state.retune!.tuning, [64, 59, 55, 50, 45, 40]);
    expect(state.retune!.octave, 1);
    expect(state.retune!.keepFrets, isTrue);
    expect(state.retune!.moved, 12);
    expect(state.retune!.unplayable, 3);
    expect(state.song.unplayableNotes, 3);
    expect(
      SongSummary.fromJson({'title': 'T', 'tracks': <Object>[]})
          .unplayableNotes,
      0,
    );
  });

  const cmaj7 = ChordSpec(root: 0, type: 'maj7', additions: [], bass: null);

  test("the edit state reads the beat's chord", () {
    EditState read(Object? chord) => EditState.fromJson({
      'position': null,
      'issues': <Object>[],
      'canUndo': false,
      'canRedo': false,
      'song': {'title': 'T', 'tracks': <Object>[]},
      'edited': false,
      'beat': {
        'duration': 4,
        'dots': 0,
        'chord': chord,
        'frets': [-1, 3, 2, 0, 0, 0],
      },
    });
    final state = read({
      'name': 'Cmaj7',
      'spec': {
        'root': 0,
        'type': 'maj7',
        'additions': <Object>[],
        'bass': null,
      },
    });
    expect(state.chordName, 'Cmaj7');
    expect(state.chordSpec, cmaj7);
    expect(state.beatFrets, [-1, 3, 2, 0, 0, 0]);
    final foreign = read({'name': 'N.C.', 'spec': null});
    expect(foreign.chordName, 'N.C.');
    expect(foreign.chordSpec, isNull);
    expect(read(null).chordName, isNull);
  });

  test('SetChord sends its chord and frets', () {
    expect(const SetChord(cmaj7, [-1, 3, 2, 0, 0, 0]).toJson(), {
      'op': 'setChord',
      'chord': {
        'root': 0,
        'type': 'maj7',
        'additions': <String>[],
        'bass': null,
      },
      'frets': [-1, 3, 2, 0, 0, 0],
    });
  });

  test('chord specs compare additions as a set', () {
    expect(
      const ChordSpec(root: 0, type: '7', additions: ['b9', '#11'], bass: null),
      const ChordSpec(root: 0, type: '7', additions: ['#11', 'b9'], bass: null),
    );
  });

  test('chord positions read their name and shapes', () {
    final positions = ChordPositions.fromJson({
      'name': 'Cmaj7',
      'positions': [
        {
          'frets': [-1, 3, 2, 0, 0, 0],
          'open': true,
          'lowestFret': 2,
        },
      ],
    });
    expect(positions.name, 'Cmaj7');
    expect(positions.positions.single.frets, [-1, 3, 2, 0, 0, 0]);
    expect(positions.positions.single.open, isTrue);
    expect(positions.positions.single.lowestFret, 2);
  });
}
