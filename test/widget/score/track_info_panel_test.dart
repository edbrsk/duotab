import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/tone.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:duoscore/features/score/track_info_panel.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Score extends MockCubit<ScoreState> implements ScoreCubit {}

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

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
  late _Editor editor;

  setUpAll(() => registerFallbackValue(Tone.clean));

  setUp(() {
    score = _Score();
    playback = _Playback();
    editor = _Editor();
    when(() => editor.state).thenReturn(const EditorState());
    when(() => playback.setTone(any(), any())).thenAnswer((_) async {});
    when(
      () => playback.setStaffView(
        any(),
        notation: any(named: 'notation'),
        tab: any(named: 'tab'),
      ),
    ).thenAnswer((_) async {});
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
              BlocProvider<EditorCubit>.value(value: editor),
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

  testWidgets("notation toggles show the drawn track's staves", (tester) async {
    await pump(tester, drawn);
    for (final label in ['Standard notation', 'Tab']) {
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, label),
      );
      expect(chip.selected, isTrue);
    }
  });

  testWidgets('turning one off calls the cubit', (tester) async {
    await pump(tester, drawn);
    await tester.tap(find.widgetWithText(FilterChip, 'Standard notation'));
    verify(() => playback.setStaffView(1, notation: false, tab: true))
        .called(1);
  });

  testWidgets('the last staff on cannot be turned off', (tester) async {
    when(() => playback.state).thenReturn(
      const PlaybackState(
        practice: PracticeSettings(
          tracks: {1: TrackPractice(tone: Tone.overdrive, showTab: false)},
        ),
      ),
    );
    await pump(tester, drawn);
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Standard notation'),
    );
    expect(chip.onSelected, isNull);
  });

  testWidgets('is empty without a drawn track', (tester) async {
    await pump(tester, const ScoreState());
    expect(find.byType(RadioListTile<Tone>), findsNothing);
  });

  testWidgets('the track name renames the track', (tester) async {
    when(() => editor.renameTrack(any(), any())).thenAnswer((_) async {});
    await pump(tester, drawn);
    await tester.tap(find.byTooltip('Rename track'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lead');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verify(() => editor.renameTrack(1, 'Lead')).called(1);
  });

  testWidgets('Retune opens the dialog and sends the chosen tuning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(951, 1400);
    when(() => editor.retune(any(), any(), octave: any(named: 'octave')))
        .thenAnswer((_) async {});
    await pump(tester, drawn);
    tester.view.physicalSize = const Size(951, 1400);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retune…'));
    await tester.pumpAndSettle();
    expect(find.text('Retune Guitar 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tuning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard E').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retune'));
    await tester.pumpAndSettle();
    verify(() => editor.retune(1, [64, 59, 55, 50, 45, 40])).called(1);
  });

  EditorState reported({int moved = 12, int unplayable = 3, int octave = 0}) =>
      EditorState(
        retune: RetuneReport(
          track: 1,
          tuning: const [64, 59, 55, 50, 45, 40],
          octave: octave,
          moved: moved,
          unplayable: unplayable,
        ),
      );

  testWidgets('the report shows the counts with Undo and the octave buttons', (
    tester,
  ) async {
    when(() => editor.state).thenReturn(reported());
    when(() => editor.undo()).thenAnswer((_) async {});
    when(() => editor.retuneOctave(any())).thenAnswer((_) async {});
    await pump(tester, drawn);
    expect(
      find.text("12 notes moved to another string, 3 can't be played"),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Octave up'));
    await tester.tap(find.text('Undo'));
    await tester.tap(find.text('Octave up'));
    await tester.tap(find.text('Octave down'));
    verify(() => editor.undo()).called(1);
    verify(() => editor.retuneOctave(1)).called(1);
    verify(() => editor.retuneOctave(-1)).called(1);
  });

  testWidgets('Octave up is disabled at +2', (tester) async {
    when(() => editor.state).thenReturn(reported(octave: 2));
    await pump(tester, drawn);
    final up = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Octave up'),
    );
    final down = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Octave down'),
    );
    expect(up.onPressed, isNull);
    expect(down.onPressed, isNotNull);
  });

  testWidgets('no report shows when both counts are zero', (tester) async {
    when(() => editor.state).thenReturn(reported(moved: 0, unplayable: 0));
    await pump(tester, drawn);
    expect(find.text('Octave up'), findsNothing);
  });
}
