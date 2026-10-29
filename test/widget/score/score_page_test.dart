import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/playback/playback_cubit.dart';
import 'package:duotab/features/playback/transport_bar.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:duotab/features/score/score_page.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../unit/features/score/score_test_data.dart';

class _Engine extends Mock implements EngineBridge {}

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

void main() {
  late _Engine engine;
  late ScoreCubit cubit;
  late _Playback playback;

  setUp(() {
    engine = _Engine();
    when(() => engine.events)
        .thenAnswer((_) => const Stream<EngineEvent>.empty());
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
    when(() => engine.open('fixture.gp'))
        .thenAnswer((_) async => drumsAndTwoGuitars);
    when(() => engine.open('beat.gp')).thenAnswer((_) async => drumsOnly);
    cubit = ScoreCubit(engine: engine);
    playback = _Playback();
    when(() => playback.state).thenReturn(const PlaybackState());
  });

  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(890, 626)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider<PlaybackCubit>.value(value: playback),
          ],
          child: const ScorePage(engineView: Text('engine view')),
        ),
      ),
    );
  }

  testWidgets('the right panel shows the drawn track', (tester) async {
    await cubit.open('fixture.gp');
    await pumpPage(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('trackPanel')),
        matching: find.text('Guitar 1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('says when a song has no guitar track', (tester) async {
    await cubit.open('beat.gp');
    await pumpPage(tester);

    expect(find.text('This song has no guitar track'), findsOneWidget);
  });

  testWidgets('hides the transport when no song is open', (tester) async {
    await pumpPage(tester);
    expect(find.byType(TransportBar), findsNothing);
  });

  testWidgets('asks to open a song when none is open', (tester) async {
    await pumpPage(tester);

    expect(find.text('Open a song from the library'), findsOneWidget);
    // The engine stays mounted even with nothing to show.
    expect(find.text('engine view', skipOffstage: false), findsOneWidget);
  });

  testWidgets('shows an error from the engine', (tester) async {
    when(
      () => engine.open('broken.gp5'),
    ).thenThrow(const EngineException('No compatible importer found for file'));
    await cubit.open('broken.gp5');
    await pumpPage(tester);

    expect(
      find.text(
        "Couldn't show this song: No compatible importer found for file",
      ),
      findsOneWidget,
    );
    expect(find.text('Open a song from the library'), findsNothing);
  });
}
