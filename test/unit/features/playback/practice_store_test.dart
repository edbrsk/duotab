import 'dart:io';

import 'package:duotab/core/storage/json_file.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/playback/practice_settings.dart';
import 'package:duotab/features/playback/practice_store.dart';
import 'package:duotab/features/playback/tone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late PracticeStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('practice_store_test');
    store = PracticeStore(JsonFile(File(p.join(dir.path, 'practice.json'))));
  });

  tearDown(() => dir.delete(recursive: true));

  const settings = PracticeSettings(
    speed: 0.75,
    looping: true,
    range: PlaybackRange(startTick: 960, endTick: 3840),
    tracks: {
      1: TrackPractice(mute: true, tone: Tone.highGain),
      2: TrackPractice(),
    },
  );

  test('round-trips practice settings', () async {
    await store.save('songs/a.gp', settings);
    final loaded = (await store.load('songs/a.gp'))!;

    expect(loaded.speed, 0.75);
    expect(loaded.looping, isTrue);
    expect(loaded.range!.startTick, 960);
    expect(loaded.range!.endTick, 3840);
    expect(loaded.tracks.keys, [1, 2]);
    expect(loaded.tracks[1]!.mute, isTrue);
    expect(loaded.tracks[1]!.solo, isFalse);
    expect(loaded.tracks[1]!.tone, Tone.highGain);
    expect(loaded.tracks[2]!.tone, isNull);
  });

  test('an unknown path loads null', () async {
    expect(await store.load('nowhere.gp'), isNull);
  });

  test('keeps other songs when saving one', () async {
    await store.save('a.gp', settings);
    await store.save('b.gp', const PracticeSettings(speed: 0.5));
    expect((await store.load('a.gp'))!.speed, 0.75);
    expect((await store.load('b.gp'))!.speed, 0.5);
  });

  test('saves of two songs at once keep both', () async {
    await Future.wait([
      store.save('a.gp', settings),
      store.save('b.gp', const PracticeSettings(speed: 0.5)),
    ]);
    expect(await store.load('a.gp'), isNotNull);
    expect(await store.load('b.gp'), isNotNull);
  });

  group('Tone', () {
    test('fromProgram knows the three tones only', () {
      expect(Tone.fromProgram(27), Tone.clean);
      expect(Tone.fromProgram(29), Tone.overdrive);
      expect(Tone.fromProgram(30), Tone.highGain);
      expect(Tone.fromProgram(24), isNull);
    });
  });
}
