import 'package:duotab/engine/protocol.dart';
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
    expect(song.tracks[1].stringCount, isNull);
    expect(song.guitarTracks.map((t) => t.name), ['Guitar 1']);
  });
}
