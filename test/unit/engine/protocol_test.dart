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
  });
}
