import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/chord_picker.dart';
import 'package:duoscore/features/editor/cursor_keys.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/editor/fret_pad.dart';
import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/tone.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:duoscore/features/score/track_info_panel.dart';
import 'package:duoscore/features/settings/settings_cubit.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Score extends MockCubit<ScoreState> implements ScoreCubit {}

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

class _Settings extends MockCubit<AppSettings> implements SettingsCubit {}

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
  late _Settings settings;

  setUpAll(() {
    registerFallbackValue(Tone.clean);
    registerFallbackValue(const SetRest());
  });

  setUp(() {
    score = _Score();
    playback = _Playback();
    editor = _Editor();
    settings = _Settings();
    when(() => settings.setChordsShown(shown: any(named: 'shown')))
        .thenAnswer((_) async {});
    when(() => settings.setTrackDetailsFolded(folded: any(named: 'folded')))
        .thenAnswer((_) async {});
    when(() => settings.setInputFolded(folded: any(named: 'folded')))
        .thenAnswer((_) async {});
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

  Future<void> pump(
    WidgetTester tester,
    ScoreState state, {
    bool editable = true,
    bool chordsShown = false,
    bool trackDetailsFolded = false,
    bool inputFolded = false,
    double height = 626,
    double textScale = 1,
  }) async {
    when(() => settings.state).thenReturn(
      AppSettings(
        chordsShown: chordsShown,
        trackDetailsFolded: trackDetailsFolded,
        inputFolded: inputFolded,
      ),
    );
    tester.view
      ..physicalSize = Size(220, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => score.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ScoreCubit>.value(value: score),
              BlocProvider<PlaybackCubit>.value(value: playback),
              BlocProvider<EditorCubit>.value(value: editor),
              BlocProvider<SettingsCubit>.value(value: settings),
            ],
            child: TrackInfoPanel(editable: editable),
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

  testWidgets('the switch labels stay on one line', (tester) async {
    await pump(tester, drawn, textScale: 1.3);
    for (final label in ['Frets', 'Chords']) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        text.size.height,
        text.getMinIntrinsicHeight(double.infinity),
        reason: label,
      );
    }
  });

  testWidgets('the panel switches between frets and chords', (tester) async {
    await pump(tester, drawn);
    expect(find.byType(FretPad), findsOneWidget);
    expect(find.byType(ChordPicker), findsNothing);
    await tester.tap(find.text('Chords'));
    verify(() => settings.setChordsShown(shown: true)).called(1);

    // A fresh tree: the mock setting doesn't emit its change.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, drawn, chordsShown: true, height: 2000);
    expect(find.byType(ChordPicker), findsOneWidget);
    expect(find.byType(FretPad), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pump(tester, drawn, editable: false);
    expect(find.text('Chords'), findsNothing);
  });

  testWidgets('a play-only panel has nothing that edits', (tester) async {
    await pump(tester, drawn, editable: false);

    expect(find.byType(FretPad), findsNothing);
    expect(find.byTooltip('Rename track'), findsNothing);
    expect(find.text('Retune…'), findsNothing);
    expect(find.text('Guitar 1'), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(find.byType(RadioListTile<Tone>), findsNWidgets(3));

    await tester.tap(find.text('High gain'));
    verify(() => playback.setTone(1, Tone.highGain)).called(1);
  });

  testWidgets("marks the track's tone and changes it", (tester) async {
    await pump(tester, drawn);
    final group = tester.widget<RadioGroup<Tone>>(
      find.byType(RadioGroup<Tone>),
    );
    expect(group.groupValue, Tone.overdrive);
    await tester.ensureVisible(find.text('High gain'));
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
    final chip = find.widgetWithText(FilterChip, 'Standard notation');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
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
    expect(find.text('Track name'), findsOneWidget);
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

  EditorState reported({
    int moved = 12,
    int unplayable = 3,
    int octave = 0,
    bool keepFrets = false,
  }) => EditorState(
    retune: RetuneReport(
      track: 1,
      tuning: const [64, 59, 55, 50, 45, 40],
      octave: octave,
      keepFrets: keepFrets,
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
    for (final label in ['Undo', 'Octave up', 'Octave down']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
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

  testWidgets('a retune keeping frets offers Undo but no octave', (
    tester,
  ) async {
    when(() => editor.state).thenReturn(reported(keepFrets: true));
    await pump(tester, drawn);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Octave up'), findsNothing);
  });

  testWidgets('no report shows when both counts are zero', (tester) async {
    when(() => editor.state).thenReturn(reported(moved: 0, unplayable: 0));
    await pump(tester, drawn);
    expect(find.text('Octave up'), findsNothing);
  });

  bool onScreen(WidgetTester tester, Finder finder, double height) {
    final box = tester.getRect(finder);
    return box.top >= 0 && box.bottom <= height;
  }

  testWidgets('the arrows stay on screen below a long chord picker', (
    tester,
  ) async {
    when(() => editor.state).thenReturn(
      const EditorState(
        position: EditPosition(track: 1, bar: 0, voice: 0, beat: 0, string: 1),
      ),
    );
    when(() => editor.command(any())).thenAnswer((_) async {});
    await pump(tester, drawn, chordsShown: true);
    expect(find.byType(ChordPicker), findsOneWidget);
    expect(onScreen(tester, find.byType(CursorKeys), 626), isTrue);
    await tester.tap(find.byTooltip('Next beat'));
    verify(() => editor.command(const Move('right'))).called(1);
  });

  testWidgets('the frets pad shares the same arrows', (tester) async {
    await pump(tester, drawn);
    expect(find.byType(FretPad), findsOneWidget);
    expect(find.byType(CursorKeys), findsOneWidget);
    expect(onScreen(tester, find.byType(CursorKeys), 626), isTrue);
  });

  testWidgets('the track part takes at most 40% and scrolls on its own', (
    tester,
  ) async {
    await pump(tester, drawn);
    final part = tester.getSize(find.byKey(const Key('track-details')));
    expect(part.height, lessThanOrEqualTo(626 * 0.4));
    await tester.ensureVisible(find.text('High gain'));
    await tester.pump();
    expect(onScreen(tester, find.byType(CursorKeys), 626), isTrue);
  });

  testWidgets('a short track part is only as tall as its contents', (
    tester,
  ) async {
    await pump(tester, drawn, height: 2000);
    final part = tester.getSize(find.byKey(const Key('track-details')));
    expect(part.height, lessThan(2000 * 0.4));
  });

  testWidgets('a folded track part shows only its name', (tester) async {
    await pump(tester, drawn, trackDetailsFolded: true);
    expect(find.text('Guitar 1'), findsOneWidget);
    expect(find.textContaining('E♭ A♭'), findsNothing);
    expect(find.textContaining('strings'), findsNothing);
    expect(find.text('Retune…'), findsNothing);
    expect(find.byType(RadioListTile<Tone>), findsNothing);
    expect(find.byType(FretPad), findsOneWidget);

    await tester.tap(find.byTooltip('Show track details'));
    verify(() => settings.setTrackDetailsFolded(folded: false)).called(1);
  });

  testWidgets('a folded input part shows only its name', (tester) async {
    await pump(tester, drawn, inputFolded: true, chordsShown: true);
    expect(find.byType(ChordPicker), findsNothing);
    expect(find.byType(CursorKeys), findsNothing);
    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Chords'), findsNothing);
    expect(find.byType(RadioListTile<Tone>), findsNWidgets(3));

    await tester.tap(find.byTooltip('Show input'));
    verify(() => settings.setInputFolded(folded: false)).called(1);
  });

  testWidgets('each open part folds from its header', (tester) async {
    await pump(tester, drawn);
    await tester.tap(find.byTooltip('Hide track details'));
    verify(() => settings.setTrackDetailsFolded(folded: true)).called(1);
    await tester.tap(find.byTooltip('Hide input'));
    verify(() => settings.setInputFolded(folded: true)).called(1);
  });

  testWidgets('a play-only panel is one part without arrows', (tester) async {
    await pump(tester, drawn, editable: false);
    expect(find.byType(CursorKeys), findsNothing);
    expect(find.byTooltip('Hide track details'), findsNothing);
  });

  testWidgets('both part headers use the same text size', (tester) async {
    await pump(tester, drawn, trackDetailsFolded: true, inputFolded: true);
    final name = tester.renderObject<RenderParagraph>(find.text('Guitar 1'));
    final input = tester.renderObject<RenderParagraph>(find.text('Input'));
    expect(input.text.style?.fontSize, name.text.style?.fontSize);
  });
}
