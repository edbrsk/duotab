import 'dart:async';
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
      1: TrackPractice(mute: true, tone: Tone.highGain, showNotation: false),
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
    expect(loaded.tracks[1]!.showNotation, isFalse);
    expect(loaded.tracks[1]!.showTab, isTrue);
  });

  test('settings saved before staff views read as both shown', () {
    final track = TrackPractice.fromJson({'mute': false, 'solo': false});
    expect(track.showNotation, isTrue);
    expect(track.showTab, isTrue);
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

  test('a load waits for saves in progress', () async {
    unawaited(store.save('a.gp', settings));
    expect((await store.load('a.gp'))?.speed, 0.75);
  });

  test('a failed save does not stop later saves', () async {
    final missing = Directory(p.join(dir.path, 'missing'));
    final failing = PracticeStore(
      JsonFile(File(p.join(missing.path, 'practice.json'))),
    );
    await expectLater(
      failing.save('a.gp', settings),
      throwsA(isA<FileSystemException>()),
    );
    missing.createSync();
    await failing.save('a.gp', settings);
    expect((await failing.load('a.gp'))?.speed, 0.75);
  });

  group('Tone', () {
    test('fromProgram knows the three tones only', () {
      expect(Tone.fromProgram(27), Tone.clean);
      expect(Tone.fromProgram(29), Tone.overdrive);
      expect(Tone.fromProgram(30), Tone.highGain);
      expect(Tone.fromProgram(24), isNull);
    });
  });

  test('forgets a deleted song', () async {
    await store.save('a.gp', settings);
    await store.save('b.gp', settings);
    await store.remove('a.gp');
    expect(await store.load('a.gp'), isNull);
    expect(await store.load('b.gp'), isNotNull);
  });

  test('moves settings to a renamed song', () async {
    await store.save('a.gp', settings);
    await store.rename('a.gp', 'c.gp');
    expect(await store.load('a.gp'), isNull);
    expect((await store.load('c.gp'))!.speed, 0.75);
  });
}
