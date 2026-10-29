import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/features/playback/playback_cubit.dart';
import 'package:duotab/features/playback/transport_bar.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

void main() {
  late _Playback playback;

  setUp(() {
    playback = _Playback();
    when(() => playback.playPause()).thenAnswer((_) async {});
    when(() => playback.stop()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, PlaybackState state) async {
    when(() => playback.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PlaybackCubit>.value(
            value: playback,
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
}
