import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/playback/playback_cubit.dart';
import 'package:duotab/features/playback/practice_settings.dart';
import 'package:duotab/features/playback/tone.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:duotab/features/score/track_info_panel.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Score extends MockCubit<ScoreState> implements ScoreCubit {}

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

const _song = SongSummary(
  title: 'Collateral',
  tracks: [
    TrackSummary(
      index: 0,
      name: 'Drums',
      kind: TrackKind.drums,
      stringCount: null,
      tuning: null,
      midiProgram: 0,
    ),
    TrackSummary(
      index: 1,
      name: 'Guitar 1',
      kind: TrackKind.guitar,
      stringCount: 6,
      tuning: [63, 58, 54, 49, 44, 39],
      midiProgram: 29,
    ),
  ],
);

void main() {
  late _Score score;
  late _Playback playback;

  setUpAll(() => registerFallbackValue(Tone.clean));

  setUp(() {
    score = _Score();
    playback = _Playback();
    when(() => playback.setTone(any(), any())).thenAnswer((_) async {});
    when(() => playback.state).thenReturn(
      const PlaybackState(
        practice: PracticeSettings(
          tracks: {
            0: TrackPractice(),
            1: TrackPractice(tone: Tone.overdrive),
          },
        ),
      ),
    );
  });

  Future<void> pump(WidgetTester tester, ScoreState state) async {
    tester.view
      ..physicalSize = const Size(220, 626)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => score.state).thenReturn(state);
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
            child: const TrackInfoPanel(),
          ),
        ),
      ),
    );
  }

  const drawn = ScoreState(song: _song, path: 'c.gp', selectedTrackIndex: 1);

  testWidgets("shows the drawn track's name, tuning and string count", (
    tester,
  ) async {
    await pump(tester, drawn);
    expect(find.text('Guitar 1'), findsOneWidget);
    expect(find.text('E♭ A♭ D♭ G♭ B♭ E♭'), findsOneWidget);
    expect(find.text('6 strings'), findsOneWidget);
  });

  testWidgets("marks the track's tone and changes it", (tester) async {
    await pump(tester, drawn);
    final group = tester.widget<RadioGroup<Tone>>(
      find.byType(RadioGroup<Tone>),
    );
    expect(group.groupValue, Tone.overdrive);
    await tester.tap(find.text('High gain'));
    verify(() => playback.setTone(1, Tone.highGain)).called(1);
  });

  testWidgets('is empty without a drawn track', (tester) async {
    await pump(tester, const ScoreState());
    expect(find.byType(RadioListTile<Tone>), findsNothing);
  });
}
