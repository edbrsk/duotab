import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'score_test_data.dart';

class _Engine extends Mock implements EngineBridge {}

void main() {
  late _Engine engine;

  setUp(() {
    engine = _Engine();
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
  });

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
}
