import 'dart:async';
import 'dart:io';

import 'package:duotab/core/duo/hinge_status_provider.dart';
import 'package:duotab/core/storage/json_file.dart';
import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/playback/playback_cubit.dart';
import 'package:duotab/features/playback/practice_settings.dart';
import 'package:duotab/features/playback/practice_store.dart';
import 'package:duotab/features/playback/tone.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:duotab/features/settings/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../score/score_test_data.dart';

class _Engine extends Mock implements EngineBridge {}

class _Store extends Mock implements PracticeStore {}

List<TrackMix> _sentMixes(_Engine engine) =>
    verify(() => engine.setTracks(captureAny())).captured.last
        as List<TrackMix>;

void main() {
  late _Engine engine;
  late StreamController<EngineEvent> events;
  late StreamController<dynamic> hingeEvents;
  late HingeStatusProvider hinge;
  late ScoreCubit score;
  late Directory dir;
  late PracticeStore practice;
  late SettingsCubit settings;
  late PlaybackCubit cubit;

  setUpAll(() {
    registerFallbackValue(<TrackMix>[]);
    registerFallbackValue(<StaffView>[]);
    registerFallbackValue(const PlaybackRange(startTick: 0, endTick: 0));
    registerFallbackValue(const PracticeSettings());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('playback_cubit_test');
    practice = PracticeStore(JsonFile(File(p.join(dir.path, 'practice.json'))));
    settings = SettingsCubit(JsonFile(File(p.join(dir.path, 'settings.json'))));
    engine = _Engine();
    events = StreamController<EngineEvent>.broadcast();
    hingeEvents = StreamController<dynamic>();
    hinge = HingeStatusProvider(hingeEvents: hingeEvents.stream);
    when(() => engine.events).thenAnswer((_) => events.stream);
    when(() => engine.play()).thenAnswer((_) async {});
    when(() => engine.pause()).thenAnswer((_) async {});
    when(() => engine.stop()).thenAnswer((_) async {});
    when(() => engine.seekBar(any())).thenAnswer((_) async {});
    when(() => engine.setTracks(any())).thenAnswer((_) async {});
    when(() => engine.setStaves(any())).thenAnswer((_) async {});
    when(() => engine.setSpeed(any())).thenAnswer((_) async {});
    when(() => engine.setLooping(looping: any(named: 'looping')))
        .thenAnswer((_) async {});
    when(() => engine.setRange(any())).thenAnswer((_) async {});
    when(
      () => engine.setPlayerOptions(
        countIn: any(named: 'countIn'),
        metronome: any(named: 'metronome'),
      ),
    ).thenAnswer((_) async {});
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
    // A new object per open, as the bridge parses a fresh summary each time.
    when(() => engine.open(any())).thenAnswer(
      (_) async => SongSummary(
        title: drumsAndTwoGuitars.title,
        tracks: drumsAndTwoGuitars.tracks,
      ),
    );
    score = ScoreCubit(engine: engine);
    cubit = PlaybackCubit(
      engine: engine,
      hinge: hinge,
      score: score,
      practice: practice,
      settings: settings,
    );
  });

  tearDown(() async {
    await cubit.close();
    await score.close();
    await settings.close();
    hinge.dispose();
    await hingeEvents.close();
    await events.close();
    await dir.delete(recursive: true);
  });

  Future<void> playing({required bool on}) async {
    events.add(EngineEvent('playerState', {'playing': on}));
    await pumpEventQueue();
  }

  test("follows the engine's player state", () async {
    await playing(on: true);
    expect(cubit.state.playing, isTrue);
    await playing(on: false);
    expect(cubit.state.playing, isFalse);
  });

  test('playPause plays when paused and pauses when playing', () async {
    await cubit.playPause();
    verify(() => engine.play()).called(1);
    await playing(on: true);
    await cubit.playPause();
    verify(() => engine.pause()).called(1);
  });

  test('pauses when the hinge closes', () async {
    await playing(on: true);
    hingeEvents.add('closed');
    await pumpEventQueue();
    verify(() => engine.pause()).called(1);
    hingeEvents.add('fullyOpen');
    await pumpEventQueue();
    verifyNever(() => engine.play());
  });

  test('an engine restart stops showing playback', () async {
    await playing(on: true);
    events.add(const EngineEvent('ready', {}));
    await pumpEventQueue();
    expect(cubit.state.playing, isFalse);
  });

  test('follows the current bar', () async {
    events.add(const EngineEvent('position', {'bar': 7}));
    await pumpEventQueue();
    expect(cubit.state.bar, 7);
  });

  test('seekBar asks the engine to seek', () async {
    await cubit.seekBar(3);
    verify(() => engine.seekBar(3)).called(1);
  });

  test('opening another song goes back to bar 0 and paused', () async {
    events.add(const EngineEvent('position', {'bar': 7}));
    await playing(on: true);
    await score.open('fixture.gp');
    await pumpEventQueue();
    expect(cubit.state.bar, 0);
    expect(cubit.state.playing, isFalse);
  });

  Future<void> openFixture() async {
    await score.open('fixture.gp');
    await pumpEventQueue();
  }

  test('opening a song sends its resolved mix', () async {
    await openFixture();
    final mixes = _sentMixes(engine);
    expect(mixes.map((m) => m.index), [0, 1, 2]);
    expect(mixes.map((m) => m.program), [29, 29, 29]);
    expect(mixes.any((m) => m.mute || m.solo), isFalse);
  });

  test('setMute updates, persists and sends', () async {
    await openFixture();
    await cubit.setMute(1, on: true);
    expect(cubit.state.practice.tracks[1]!.mute, isTrue);
    expect((await practice.load('fixture.gp'))!.tracks[1]!.mute, isTrue);
    final mixes = _sentMixes(engine);
    expect(mixes.single.index, 1);
    expect(mixes.single.mute, isTrue);
  });

  test('setTone sends the tone program', () async {
    await openFixture();
    await cubit.setTone(2, Tone.highGain);
    expect(_sentMixes(engine).single.program, 30);
    expect(cubit.state.practice.tracks[2]!.tone, Tone.highGain);
  });

  test('reapplies practice after the engine reopens the song', () async {
    await openFixture();
    await cubit.setMute(1, on: true);
    events.add(const EngineEvent('ready', {}));
    await pumpEventQueue();
    await pumpEventQueue();
    final mixes = _sentMixes(engine);
    expect(mixes, hasLength(3));
    expect(mixes[1].mute, isTrue);
  });

  test('setSpeed clamps, persists and sends', () async {
    await openFixture();
    await cubit.setSpeed(2);
    expect(cubit.state.practice.speed, 1.5);
    verify(() => engine.setSpeed(1.5)).called(1);
    expect((await practice.load('fixture.gp'))!.speed, 1.5);
  });

  test('a range from the engine is kept and saved', () async {
    await openFixture();
    events.add(
      const EngineEvent('rangeChanged', {
        'range': {'startTick': 960, 'endTick': 3840},
      }),
    );
    await pumpEventQueue();
    expect(cubit.state.practice.range!.endTick, 3840);
    expect((await practice.load('fixture.gp'))!.range!.startTick, 960);

    events.add(const EngineEvent('rangeChanged', {'range': null}));
    await pumpEventQueue();
    expect(cubit.state.practice.range, isNull);
  });

  test('opening a song sends speed, looping and range', () async {
    await practice.save(
      'fixture.gp',
      const PracticeSettings(
        speed: 0.5,
        looping: true,
        range: PlaybackRange(startTick: 0, endTick: 1920),
      ),
    );
    await openFixture();
    verify(() => engine.setSpeed(0.5)).called(1);
    verify(() => engine.setLooping(looping: true)).called(1);
    final range =
        verify(() => engine.setRange(captureAny())).captured.last
            as PlaybackRange;
    expect(range.endTick, 1920);
  });

  test('sends player options on start and on change', () async {
    await pumpEventQueue();
    verify(() => engine.setPlayerOptions(countIn: false, metronome: false))
        .called(1);
    await settings.setCountIn(on: true);
    await pumpEventQueue();
    verify(() => engine.setPlayerOptions(countIn: true, metronome: false))
        .called(1);
  });

  test('resends player options after the engine restarts', () async {
    await pumpEventQueue();
    clearInteractions(engine);
    events.add(const EngineEvent('ready', {}));
    await pumpEventQueue();
    verify(() => engine.setPlayerOptions(countIn: false, metronome: false))
        .called(1);
  });

  test(
    'opening a song sends only staff views that differ from the default',
    () async {
      await openFixture();
      verifyNever(() => engine.setStaves(any()));

      await practice.save(
        'fixture.gp',
        const PracticeSettings(tracks: {1: TrackPractice(showNotation: false)}),
      );
      await openFixture();
      final views =
          verify(() => engine.setStaves(captureAny())).captured.single
              as List<StaffView>;
      expect(views.single.index, 1);
      expect(views.single.notation, isFalse);
      expect(views.single.tab, isTrue);
    },
  );

  test('setStaffView updates, persists and sends', () async {
    await openFixture();
    await cubit.setStaffView(2, notation: true, tab: false);
    expect(cubit.state.practice.tracks[2]!.showTab, isFalse);
    expect((await practice.load('fixture.gp'))!.tracks[2]!.showTab, isFalse);
    final views =
        verify(() => engine.setStaves(captureAny())).captured.last
            as List<StaffView>;
    expect(views.single.tab, isFalse);
  });

  group('while a song settings load', () {
    late _Store slowStore;
    late Completer<PracticeSettings?> load;
    late PlaybackCubit slow;

    setUp(() {
      slowStore = _Store();
      load = Completer<PracticeSettings?>();
      when(() => slowStore.load(any())).thenAnswer((_) => load.future);
      when(() => slowStore.save(any(), any())).thenAnswer((_) async {});
      slow = PlaybackCubit(
        engine: engine,
        hinge: hinge,
        score: score,
        practice: slowStore,
        settings: settings,
      );
    });

    tearDown(() => slow.close());

    test('the previous song practice is cleared from view', () async {
      load.complete(
        const PracticeSettings(tracks: {1: TrackPractice(mute: true)}),
      );
      await openFixture();
      expect(slow.state.practice.tracks[1]!.mute, isTrue);

      load = Completer<PracticeSettings?>();
      await openFixture();
      expect(slow.state.practice.tracks, isEmpty);
    });

    test('a range event is not saved under the opening song', () async {
      await openFixture();
      events.add(
        const EngineEvent('rangeChanged', {
          'range': {'startTick': 0, 'endTick': 960},
        }),
      );
      await pumpEventQueue();
      verifyNever(() => slowStore.save(any(), any()));
    });

    test('edits wait for the song settings', () async {
      await openFixture();
      await slow.setMute(1, on: true);
      verifyNever(() => slowStore.save(any(), any()));
      load.complete(null);
      await pumpEventQueue();
      await slow.setMute(1, on: true);
      verify(() => slowStore.save('fixture.gp', any())).called(1);
    });
  });
}
