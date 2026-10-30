import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/playback/practice_moves.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/tone.dart';
import 'package:flutter_test/flutter_test.dart';

import '../score/score_test_data.dart';

SongSummary _song(List<(String, int)> tracks) => SongSummary(
  title: 'S',
  tracks: [
    for (final (i, (name, channel)) in tracks.indexed)
      track(i, name, TrackKind.guitar, channel: channel),
  ],
);

void main() {
  const clean = TrackPractice(tone: Tone.clean);
  const lead = TrackPractice(tone: Tone.highGain, volumeDb: -6);
  final before = _song([('A', 0), ('B', 2), ('C', 4)]);
  final practice = {0: clean, 1: lead, 2: const TrackPractice(mute: true)};

  test('a move takes each practice along', () {
    final moved = movePractice(
      before,
      _song([('B', 2), ('A', 0), ('C', 4)]),
      practice,
    );
    expect(moved[0], lead);
    expect(moved[1], clean);
    expect(moved[2]!.mute, isTrue);
  });

  test('a removal drops one and shifts the rest', () {
    final removed = movePractice(before, _song([('A', 0), ('C', 4)]), practice);
    expect(removed.keys, [0, 1]);
    expect(removed[0], clean);
    expect(removed[1]!.mute, isTrue);
  });

  test('an added track has no practice yet', () {
    final added = movePractice(
      before,
      _song([('A', 0), ('B', 2), ('C', 4), ('D', 6)]),
      practice,
    );
    expect(added.containsKey(3), isFalse);
    expect(added[1], lead);
  });

  test('repeated channels match in order', () {
    final shared = _song([('A', 9), ('B', 9)]);
    final moved = movePractice(shared, _song([('A', 9), ('B', 9)]), {
      0: clean,
      1: lead,
    });
    expect(moved[0], clean);
    expect(moved[1], lead);
  });

  test("a new track on a removed track's channel starts fresh", () {
    final parked = <String, TrackPractice>{};
    final removed = _song([('A', 0), ('C', 4)]);
    movePractice(before, removed, practice, parked: parked);
    final added = movePractice(
      removed,
      _song([('A', 0), ('C', 4), ('Guitar 1', 2)]),
      {0: clean, 1: const TrackPractice(mute: true)},
      parked: parked,
    );
    expect(added.containsKey(2), isFalse);
    final undone = movePractice(removed, before, {
      0: clean,
      1: const TrackPractice(mute: true),
    }, parked: parked);
    expect(undone[1], lead);
  });
}
