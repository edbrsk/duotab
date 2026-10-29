import 'dart:async';

import 'package:duotab/core/duo/hinge_status_provider.dart';
import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/playback/playback_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Engine extends Mock implements EngineBridge {}

void main() {
  late _Engine engine;
  late StreamController<EngineEvent> events;
  late StreamController<dynamic> hingeEvents;
  late HingeStatusProvider hinge;
  late PlaybackCubit cubit;

  setUp(() {
    engine = _Engine();
    events = StreamController<EngineEvent>.broadcast();
    hingeEvents = StreamController<dynamic>();
    hinge = HingeStatusProvider(hingeEvents: hingeEvents.stream);
    when(() => engine.events).thenAnswer((_) => events.stream);
    when(() => engine.play()).thenAnswer((_) async {});
    when(() => engine.pause()).thenAnswer((_) async {});
    when(() => engine.stop()).thenAnswer((_) async {});
    cubit = PlaybackCubit(engine: engine, hinge: hinge);
  });

  tearDown(() async {
    await cubit.close();
    hinge.dispose();
    await hingeEvents.close();
    await events.close();
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
}
