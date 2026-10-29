import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/playback/playback_cubit.dart';
import 'package:duotab/features/playback/practice_settings.dart';
import 'package:duotab/features/playback/transport_bar.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../unit/features/score/score_test_data.dart';

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

class _Score extends MockCubit<ScoreState> implements ScoreCubit {}

final _song = SongSummary(
  title: drumsAndTwoGuitars.title,
  tracks: drumsAndTwoGuitars.tracks,
  bars: [
    for (final i in [0, 1, 2])
      BarInfo(index: i, startTick: i * 3840, startMs: i * 2000, tempo: 120),
  ],
);

void main() {
  late _Playback playback;
  late _Score score;

  setUp(() {
    playback = _Playback();
    score = _Score();
    when(() => playback.playPause()).thenAnswer((_) async {});
    when(() => playback.stop()).thenAnswer((_) async {});
    when(() => playback.setSpeed(any())).thenAnswer((_) async {});
    when(() => playback.setLooping(on: any(named: 'on')))
        .thenAnswer((_) async {});
    when(() => score.state)
        .thenReturn(ScoreState(song: _song, path: 'fixture.gp'));
  });

  Future<void> pump(WidgetTester tester, PlaybackState state) async {
    when(() => playback.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<PlaybackCubit>.value(value: playback),
              BlocProvider<ScoreCubit>.value(value: score),
            ],
            child: const TransportBar(),
          ),
        ),
      ),
    );
  }

  testWidgets('shows play, then pause while playing', (tester) async {
    final states = StreamController<PlaybackState>();
    whenListen(playback, states.stream, initialState: const PlaybackState());
    await pump(tester, const PlaybackState());
    expect(find.byTooltip('Play'), findsOneWidget);
    when(() => playback.state).thenReturn(const PlaybackState(playing: true));
    states.add(const PlaybackState(playing: true));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);
    await states.close();
  });

  testWidgets('buttons call the cubit', (tester) async {
    await pump(tester, const PlaybackState());
    await tester.tap(find.byTooltip('Play'));
    verify(() => playback.playPause()).called(1);
    await tester.tap(find.byTooltip('Stop'));
    verify(() => playback.stop()).called(1);
  });

  testWidgets("shows the current bar's tempo at the chosen speed", (
    tester,
  ) async {
    await pump(
      tester,
      const PlaybackState(bar: 2, practice: PracticeSettings(speed: 0.75)),
    );
    expect(find.text('♩ = 90'), findsOneWidget);
  });

  testWidgets('speed shortcuts set 50, 75 and 100 percent', (tester) async {
    await pump(tester, const PlaybackState());
    for (final (label, speed) in [('50%', 0.5), ('75%', 0.75), ('100%', 1.0)]) {
      await tester.tap(find.byKey(const Key('speedButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, label));
      await tester.pumpAndSettle();
      verify(() => playback.setSpeed(speed)).called(1);
    }
  });

  testWidgets('loop toggle sets looping', (tester) async {
    await pump(tester, const PlaybackState());
    await tester.tap(find.byTooltip('Loop'));
    verify(() => playback.setLooping(on: true)).called(1);
  });
}
