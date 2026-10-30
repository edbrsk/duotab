import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/resolve_practice.dart';
import 'package:duoscore/features/playback/tone.dart';
import 'package:flutter_test/flutter_test.dart';

import '../score/score_test_data.dart';

SongSummary song(List<(TrackKind, int)> tracks) => SongSummary(
  title: 'S',
  tracks: [
    for (final (i, (kind, program)) in tracks.indexed)
      TrackSummary(
        index: i,
        name: 'T$i',
        kind: kind,
        stringCount: kind == TrackKind.guitar ? 6 : null,
        tuning: kind == TrackKind.guitar
            ? const [64, 59, 55, 50, 45, 40]
            : null,
        midiProgram: program,
      ),
  ],
);

void main() {
  test('guitar tracks keep a file program that is a tone', () {
    final p = resolvePractice(song([(TrackKind.guitar, 29)]), null, Tone.clean);
    expect(p.tracks[0]!.tone, Tone.overdrive);
  });

  test('other guitar programs start with the default tone', () {
    final p = resolvePractice(
      song([(TrackKind.guitar, 25)]),
      null,
      Tone.highGain,
    );
    expect(p.tracks[0]!.tone, Tone.highGain);
  });

  test('saved settings win', () {
    final p = resolvePractice(
      drumsAndTwoGuitars,
      const PracticeSettings(
        speed: 0.5,
        tracks: {
          1: TrackPractice(mute: true, tone: Tone.clean, toneChosen: true),
        },
      ),
      Tone.highGain,
    );
    expect(p.speed, 0.5);
    expect(p.tracks[1]!.tone, Tone.clean);
    expect(p.tracks[1]!.mute, isTrue);
    expect(p.tracks[2]!.tone, Tone.overdrive);
  });

  test('non-guitar tracks have no tone', () {
    final p = resolvePractice(drumsAndTwoGuitars, null, Tone.clean);
    expect(p.tracks[0]!.tone, isNull);
  });

  test('resolvePractice ignores tracks the song no longer has', () {
    final p = resolvePractice(
      drumsAndTwoGuitars,
      const PracticeSettings(tracks: {9: TrackPractice(mute: true)}),
      Tone.clean,
    );
    expect(p.tracks.keys, [0, 1, 2]);
  });

  test("the volume resolves to the file's level", () {
    const song = SongSummary(
      title: 'S',
      tracks: [
        TrackSummary(
          index: 0,
          name: 'G',
          kind: TrackKind.guitar,
          stringCount: 6,
          tuning: [64, 59, 55, 50, 45, 40],
          midiProgram: 29,
          volume: 9,
        ),
      ],
    );
    expect(resolvePractice(song, null, Tone.clean).tracks[0]!.volume, 9);
    const saved = PracticeSettings(tracks: {0: TrackPractice(volume: 3)});
    expect(resolvePractice(song, saved, Tone.clean).tracks[0]!.volume, 3);
  });

  test('a default tone change reaches tracks left at the default', () {
    final left = resolvePractice(
      song([(TrackKind.guitar, 0)]),
      const PracticeSettings(tracks: {0: TrackPractice(tone: Tone.clean)}),
      Tone.overdrive,
    );
    expect(left.tracks[0]!.tone, Tone.overdrive);
    final chosen = resolvePractice(
      song([(TrackKind.guitar, 0)]),
      const PracticeSettings(
        tracks: {0: TrackPractice(tone: Tone.clean, toneChosen: true)},
      ),
      Tone.overdrive,
    );
    expect(chosen.tracks[0]!.tone, Tone.clean);
  });

  test('a tone saved before the choice was recorded counts as chosen', () {
    expect(TrackPractice.fromJson({'tone': 'clean'}).toneChosen, isTrue);
    expect(
      TrackPractice.fromJson({'tone': 'clean', 'toneChosen': false}).toneChosen,
      isFalse,
    );
    expect(TrackPractice.fromJson({}).toneChosen, isFalse);
  });

  test('a stored speed or range outside the song is dropped on load', () {
    const bars = SongSummary(
      title: 'S',
      tracks: [],
      bars: [
        BarInfo(index: 0, startTick: 0, startMs: 0, tempo: 120),
        BarInfo(index: 1, startTick: 3840, startMs: 2000, tempo: 120),
      ],
    );
    final p = resolvePractice(
      bars,
      const PracticeSettings(
        speed: 3,
        range: PlaybackRange(startTick: 9000, endTick: 12000),
      ),
      Tone.clean,
    );
    expect(p.speed, 1.5);
    expect(p.range, isNull);
    final kept = resolvePractice(
      bars,
      const PracticeSettings(
        range: PlaybackRange(startTick: 960, endTick: 4800),
      ),
      Tone.clean,
    );
    expect(kept.range, isNotNull);
  });
}
