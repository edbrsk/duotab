import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:duoscore/features/score/track_drawer.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../unit/features/score/score_test_data.dart';

class _Score extends MockCubit<ScoreState> implements ScoreCubit {}

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

const _barCount = 40;

SongSummary _song(List<TrackSummary> tracks) => SongSummary(
  title: 'Fixture',
  tracks: [
    for (final t in tracks)
      TrackSummary(
        index: t.index,
        name: t.name,
        kind: t.kind,
        stringCount: t.stringCount,
        tuning: t.tuning,
        midiProgram: t.midiProgram,
        barsWithNotes: [for (var b = 0; b < _barCount; b++) b.isEven],
      ),
  ],
  bars: [
    for (var b = 0; b < _barCount; b++)
      BarInfo(
        index: b,
        startTick: b * 3840,
        startMs: b * 2000,
        tempo: 120,
        section: switch (b) {
          0 => const Section(marker: 'A', text: 'Intro'),
          16 => const Section(marker: 'B', text: 'Verse'),
          _ => null,
        },
      ),
  ],
);

void main() {
  late _Score score;
  late _Playback playback;

  setUp(() {
    score = _Score();
    playback = _Playback();
    when(() => score.selectTrack(any())).thenAnswer((_) async {});
    when(() => playback.seekBar(any())).thenAnswer((_) async {});
    when(() => playback.setMute(any(), on: any(named: 'on')))
        .thenAnswer((_) async {});
    when(() => playback.setSolo(any(), on: any(named: 'on')))
        .thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    int bar = 0,
    List<TrackSummary>? tracks,
  }) async {
    tester.view
      ..physicalSize = const Size(890, 626)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => score.state).thenReturn(
      ScoreState(
        song: _song(tracks ?? drumsAndTwoGuitars.tracks),
        path: 'fixture.gp',
        selectedTrackIndex: 1,
      ),
    );
    when(() => playback.state).thenReturn(
      PlaybackState(
        bar: bar,
        practice: const PracticeSettings(
          tracks: {
            0: TrackPractice(),
            1: TrackPractice(),
            2: TrackPractice(solo: true),
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ScoreCubit>.value(value: score),
              BlocProvider<PlaybackCubit>.value(value: playback),
            ],
            child: const Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: 500, child: TrackDrawer()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset barCell(WidgetTester tester, int track, int bar) =>
      tester.getTopLeft(find.byKey(ValueKey('barRow-$track'))) +
      Offset(kBarCellWidth * bar + 2, 10);

  testWidgets('lists every track with mute and solo', (tester) async {
    await pump(tester);
    for (final name in ['Drums', 'Guitar 1', 'Guitar 2']) {
      expect(find.text(name), findsOneWidget);
      expect(find.byTooltip('Mute $name'), findsOneWidget);
      expect(find.byTooltip('Solo $name'), findsOneWidget);
    }
  });

  testWidgets('mute and solo call the cubit', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Mute Drums'));
    verify(() => playback.setMute(0, on: true)).called(1);
    await tester.tap(find.byTooltip('Solo Guitar 2'));
    verify(() => playback.setSolo(2, on: false)).called(1);
  });

  testWidgets(
    "tapping a guitar track's cell selects it and seeks to that bar",
    (tester) async {
      await pump(tester);
      await tester.tapAt(barCell(tester, 2, 5));
      await tester.pump();
      verifyInOrder([() => score.selectTrack(2), () => playback.seekBar(5)]);
    },
  );

  testWidgets('tapping a drums cell seeks without changing the drawn track', (
    tester,
  ) async {
    await pump(tester);
    await tester.tapAt(barCell(tester, 0, 3));
    await tester.pump();
    verify(() => playback.seekBar(3)).called(1);
    verifyNever(() => score.selectTrack(any()));
  });

  testWidgets('tapping a track name selects a guitar track', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Guitar 2'));
    verify(() => score.selectTrack(2)).called(1);
    await tester.tap(find.text('Drums'));
    verifyNever(() => score.selectTrack(0));
  });

  testWidgets('marks the current bar', (tester) async {
    await pump(tester, bar: 6);
    final marker = tester.getTopLeft(find.byKey(const Key('currentBarMarker')));
    final row = tester.getTopLeft(find.byKey(const ValueKey('barRow-1')));
    expect(marker.dx - row.dx, 6 * kBarCellWidth);
  });

  testWidgets('keeps the current bar in view', (tester) async {
    await pump(tester, bar: 39);
    final grid = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('barGrid')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(grid.position.pixels, greaterThan(0));
  });

  testWidgets('shows section markers with start times', (tester) async {
    await pump(tester);
    expect(find.text('A 0:00'), findsOneWidget);
    expect(find.text('B 0:32'), findsOneWidget);
  });

  testWidgets("collapsed shows only the drawn track's row", (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('drawerToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trackRow-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('trackRow-0')), findsNothing);
    expect(find.byKey(const ValueKey('trackRow-2')), findsNothing);
  });

  testWidgets('caps its height at 40% of the screen', (tester) async {
    await pump(
      tester,
      tracks: [
        for (var i = 0; i < 12; i++) track(i, 'Track $i', TrackKind.guitar),
      ],
    );
    final drawer = tester.getRect(find.byType(TrackDrawer));
    expect(drawer.height, lessThanOrEqualTo(626 * kDrawerMaxHeightFraction));
    // The last rows are below the drawer until it is scrolled.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('trackRow-11'))).dy,
      greaterThan(drawer.bottom),
    );
  });
}
