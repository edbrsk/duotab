import 'dart:async';
import 'dart:io';

import 'package:duoscore/core/duo/hinge_status_provider.dart';
import 'package:duoscore/core/storage/json_file.dart';
import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/practice_store.dart';
import 'package:duoscore/features/playback/tone.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:duoscore/features/settings/settings_cubit.dart';
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
  late StreamController<Duration> latency;
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
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('playback_cubit_test');
    practice = PracticeStore(JsonFile(File(p.join(dir.path, 'practice.json'))));
    settings = SettingsCubit(JsonFile(File(p.join(dir.path, 'settings.json'))));
    engine = _Engine();
    events = StreamController<EngineEvent>.broadcast();
    hingeEvents = StreamController<dynamic>();
    latency = StreamController<Duration>();
    hinge = HingeStatusProvider(hingeEvents: hingeEvents.stream);
    when(() => engine.events).thenAnswer((_) => events.stream);
    when(() => engine.play()).thenAnswer((_) async {});
    when(() => engine.pause()).thenAnswer((_) async {});
    when(() => engine.stop()).thenAnswer((_) async {});
    when(() => engine.seekBar(any())).thenAnswer((_) async {});
    when(() => engine.setTracks(any())).thenAnswer((_) async {});
    when(() => engine.setMaster(any())).thenAnswer((_) async {});
    when(() => engine.setMeters(on: any(named: 'on'))).thenAnswer((_) async {});
    when(() => engine.setOutputLatency(any())).thenAnswer((_) async {});
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
      outputLatency: latency.stream,
    );
  });

  tearDown(() async {
    await cubit.close();
    await score.close();
    await settings.close();
    hinge.dispose();
    await hingeEvents.close();
    await latency.close();
    await events.close();
    // Queued behind any save the cubit started without awaiting, so the
    // folder outlives it.
    await practice.remove('');
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

  test('unfolding pauses too', () async {
    await playing(on: true);
    hingeEvents.add('closed');
    await pumpEventQueue();
    await playing(on: true);
    hingeEvents.add('fullyOpen');
    await pumpEventQueue();
    verify(() => engine.pause()).called(2);
  });

  test("moving between partly and fully open doesn't pause", () async {
    hingeEvents.add('fullyOpen');
    await pumpEventQueue();
    await playing(on: true);
    hingeEvents.add('partiallyOpen');
    await pumpEventQueue();
    hingeEvents.add('fullyOpen');
    await pumpEventQueue();
    verifyNever(() => engine.pause());
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

  test(
    'closing the song stops showing playback and saves nothing for it',
    () async {
      await openFixture();
      await playing(on: true);
      events.add(const EngineEvent('position', {'bar': 7}));
      await score.closeSong();
      await pumpEventQueue();
      expect(cubit.state.playing, isFalse);
      expect(cubit.state.bar, 0);
      await practice.remove('fixture.gp');
      await cubit.setSpeed(0.5);
      await pumpEventQueue();
      expect(await practice.load('fixture.gp'), isNull);
    },
  );

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

  test('opening a song sends a saved slash view', () async {
    await practice.save(
      'fixture.gp',
      const PracticeSettings(tracks: {1: TrackPractice(showSlash: true)}),
    );
    await openFixture();
    final views =
        verify(() => engine.setStaves(captureAny())).captured.single
            as List<StaffView>;
    expect(views.single.index, 1);
    expect(views.single.slash, isTrue);
    expect(views.single.notation, isTrue);
  });

  test('setStaffView sends slash and numbered', () async {
    await openFixture();
    await cubit.setStaffView(
      1,
      notation: true,
      tab: true,
      slash: true,
      numbered: false,
    );
    expect(cubit.state.practice.tracks[1]!.showSlash, isTrue);
    expect((await practice.load('fixture.gp'))!.tracks[1]!.showSlash, isTrue);
    final views =
        verify(() => engine.setStaves(captureAny())).captured.last
            as List<StaffView>;
    expect(views.single.slash, isTrue);
    expect(views.single.numbered, isFalse);
  });

  test('setStaffView never hides both notation and tab', () async {
    await openFixture();
    clearInteractions(engine);
    await cubit.setStaffView(
      1,
      notation: false,
      tab: false,
      slash: true,
      numbered: true,
    );
    verifyNever(() => engine.setStaves(any()));
    expect(cubit.state.practice.tracks[1]!.showNotation, isTrue);
  });

  test('setStaffView updates, persists and sends', () async {
    await openFixture();
    await cubit.setStaffView(
      2,
      notation: true,
      tab: false,
      slash: false,
      numbered: false,
    );
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

    setUp(() async {
      // Only the slow cubit is under test; the outer one would save to the
      // temp folder while tearDown deletes it.
      await cubit.close();
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

  test(
    "setVolumeDb sends the track's dB and pan, and saves on release",
    () async {
      await openFixture();
      await cubit.setVolumeDb(1, -6, save: false);
      final mix = _sentMixes(engine).single;
      expect([mix.volumeDb, mix.pan], [-6.0, 0.0]);
      expect(cubit.state.practice.tracks[1]!.volumeDb, -6);
      expect(
        (await practice.load('fixture.gp'))?.tracks[1]?.volumeDb,
        isNot(-6),
      );
      await cubit.setVolumeDb(1, -4.5);
      expect((await practice.load('fixture.gp'))!.tracks[1]!.volumeDb, -4.5);
    },
  );

  test('setPan saves on release', () async {
    await openFixture();
    await cubit.setPan(1, -0.5, save: false);
    expect(_sentMixes(engine).single.pan, -0.5);
    expect((await practice.load('fixture.gp'))?.tracks[1]?.pan, isNot(-0.5));
    await cubit.setPan(1, -0.5);
    expect((await practice.load('fixture.gp'))!.tracks[1]!.pan, -0.5);
  });

  test('setMasterDb sends setMaster and saves', () async {
    await openFixture();
    await cubit.setMasterDb(-6);
    verify(() => engine.setMaster(-6)).called(1);
    expect((await practice.load('fixture.gp'))!.masterDb, -6);
  });

  test('showMeters turns the engine meters on and off', () async {
    await cubit.showMeters(on: true);
    await cubit.showMeters(on: false);
    verifyInOrder([
      () => engine.setMeters(on: true),
      () => engine.setMeters(on: false),
    ]);
  });

  test('the output latency reaches the engine', () async {
    latency.add(const Duration(milliseconds: 180));
    await pumpEventQueue();
    verify(() => engine.setOutputLatency(const Duration(milliseconds: 180)))
        .called(1);
  });

  test('a restarted engine gets the meters and latency again', () async {
    await cubit.showMeters(on: true);
    latency.add(const Duration(milliseconds: 180));
    await pumpEventQueue();
    clearInteractions(engine);
    events.add(const EngineEvent('ready', {}));
    await pumpEventQueue();
    verify(() => engine.setMeters(on: true)).called(1);
    verify(() => engine.setOutputLatency(const Duration(milliseconds: 180)))
        .called(1);
  });

  test('opening a song sends its master', () async {
    await openFixture();
    verify(() => engine.setMaster(0)).called(1);
  });

  test('−∞ sends a null dB', () {
    const mix = TrackMix(
      index: 0,
      mute: false,
      solo: false,
      program: 29,
      volumeDb: double.negativeInfinity,
      pan: 0,
    );
    expect(mix.toJson()['volumeDb'], isNull);
  });

  test('a levels event updates the meters without a new state', () async {
    await openFixture();
    final states = <PlaybackState>[];
    final sub = cubit.stream.listen(states.add);
    events.add(
      const EngineEvent('levels', {
        'tracks': [
          [-12.0, -14.0],
          null,
          null,
        ],
        'master': [-10.0, -10.0],
      }),
    );
    await pumpEventQueue();
    await sub.cancel();
    expect(states, isEmpty);
    expect(cubit.levels.value!.tracks[0]!.left, -12);
    expect(cubit.levels.value!.tracks[1], isNull);
    expect(cubit.levels.value!.master!.right, -10);
  });

  test(
    'practice follows its track through a move, a removal and an undo',
    () async {
      await openFixture();
      await cubit.setTone(1, Tone.highGain);
      await cubit.setVolumeDb(2, -6);
      clearInteractions(engine);
      final [drums, one, two] = drumsAndTwoGuitars.tracks;
      SongSummary song(List<TrackSummary> tracks) => SongSummary(
        title: 'Fixture',
        tracks: [
          for (final (i, t) in tracks.indexed)
            track(i, t.name, t.kind, channel: t.channel),
        ],
      );
      Future<void> edit(List<TrackSummary> tracks) async {
        score.applyEdit(song(tracks));
        await pumpEventQueue();
      }

      await edit([two, drums, one]);
      expect(cubit.state.practice.tracks[0]!.volumeDb, -6);
      expect(cubit.state.practice.tracks[2]!.tone, Tone.highGain);
      expect(
        (await practice.load('fixture.gp'))!.tracks[2]!.tone,
        Tone.highGain,
      );
      expect(_sentMixes(engine).map((m) => m.volumeDb).first, -6);

      await edit([drums, one]);
      expect(cubit.state.practice.tracks[1]!.tone, Tone.highGain);
      expect(cubit.state.practice.tracks.length, 2);

      await edit([drums, one, two]);
      expect(cubit.state.practice.tracks[1]!.tone, Tone.highGain);
      expect(cubit.state.practice.tracks[2]!.volumeDb, -6);
    },
  );
}
