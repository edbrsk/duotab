import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'score_test_data.dart';

class _Engine extends Mock implements EngineBridge {}

void main() {
  late _Engine engine;
  late StreamController<EngineEvent> events;

  setUp(() {
    engine = _Engine();
    events = StreamController<EngineEvent>.broadcast();
    when(() => engine.events).thenAnswer((_) => events.stream);
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
  });

  tearDown(() => events.close());

  blocTest<ScoreCubit, ScoreState>(
    'opening selects and renders the first guitar track',
    setUp: () =>
        when(() => engine.open('fixture.gp'))
            .thenAnswer((_) async => drumsAndTwoGuitars),
    build: () => ScoreCubit(engine: engine),
    act: (cubit) => cubit.open('fixture.gp'),
    expect: () => [
      isA<ScoreState>().having((s) => s.loading, 'loading', isTrue),
      isA<ScoreState>()
          .having((s) => s.loading, 'loading', isFalse)
          .having((s) => s.path, 'path', 'fixture.gp')
          .having((s) => s.song?.title, 'title', 'Fixture')
          .having((s) => s.selectedTrackIndex, 'selected', 1),
    ],
    verify: (_) => verify(() => engine.renderTrack(1)).called(1),
  );

  blocTest<ScoreCubit, ScoreState>(
    'a song without guitar tracks selects none',
    setUp: () =>
        when(() => engine.open('beat.gp')).thenAnswer((_) async => drumsOnly),
    build: () => ScoreCubit(engine: engine),
    act: (cubit) => cubit.open('beat.gp'),
    skip: 1,
    expect: () => [
      isA<ScoreState>().having((s) => s.selectedTrackIndex, 'selected', isNull),
    ],
    verify: (_) => verifyNever(() => engine.renderTrack(any())),
  );

  blocTest<ScoreCubit, ScoreState>(
    'reports an engine error',
    setUp: () => when(
      () => engine.open('broken.gp5'),
    ).thenThrow(const EngineException('No compatible importer found for file')),
    build: () => ScoreCubit(engine: engine),
    act: (cubit) => cubit.open('broken.gp5'),
    skip: 1,
    expect: () => [
      isA<ScoreState>()
          .having((s) => s.loading, 'loading', isFalse)
          .having((s) => s.error, 'error', contains('No compatible importer')),
    ],
  );

  test('keeps the opened song when rendering fails', () async {
    when(() => engine.open('fixture.gp'))
        .thenAnswer((_) async => drumsAndTwoGuitars);
    when(() => engine.renderTrack(1))
        .thenThrow(const EngineTimeout('renderTrack'));
    final cubit = ScoreCubit(engine: engine);
    addTearDown(cubit.close);

    await cubit.open('fixture.gp');

    expect(cubit.state.song?.title, 'Fixture');
    expect(cubit.state.path, 'fixture.gp');
    expect(cubit.state.selectedTrackIndex, 1);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.loading, isFalse);
  });

  test('reports a failed track switch instead of throwing', () async {
    when(() => engine.open('fixture.gp'))
        .thenAnswer((_) async => drumsAndTwoGuitars);
    final cubit = ScoreCubit(engine: engine);
    addTearDown(cubit.close);
    await cubit.open('fixture.gp');
    when(() => engine.renderTrack(2))
        .thenThrow(const EngineException('no track 2'));

    await cubit.selectTrack(2);

    expect(cubit.state.error, contains('no track 2'));
    expect(cubit.state.selectedTrackIndex, 1);
  });

  test('reopens the song and track after the engine restarts', () async {
    when(() => engine.open('fixture.gp'))
        .thenAnswer((_) async => drumsAndTwoGuitars);
    final cubit = ScoreCubit(engine: engine);
    addTearDown(cubit.close);
    await cubit.open('fixture.gp');
    await cubit.selectTrack(2);

    events.add(const EngineEvent('ready', {}));
    await pumpEventQueue();

    verify(() => engine.open('fixture.gp')).called(2);
    verify(() => engine.renderTrack(2)).called(2);
    expect(cubit.state.selectedTrackIndex, 2);
  });
}
