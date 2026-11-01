import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/chord_diagram.dart';
import 'package:duoscore/features/editor/chord_picker.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../unit/features/score/score_test_data.dart';

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

class _Score extends MockCubit<ScoreState> implements ScoreCubit {}

const _at = EditPosition(track: 1, bar: 0, voice: 0, beat: 1, string: 1);
const _cmaj7 = ChordSpec(root: 0, type: 'maj7', additions: [], bass: null);
const _cm7 = ChordSpec(root: 0, type: 'm7', additions: [], bass: null);
const _positions = ChordPositions(
  name: 'Cmaj7',
  positions: [
    ChordPosition(frets: [-1, 3, 2, 0, 0, 0], open: true, lowestFret: 2),
    ChordPosition(frets: [-1, 3, 5, 4, 5, 3], open: false, lowestFret: 3),
    ChordPosition(frets: [8, -1, 9, 9, 8, 8], open: false, lowestFret: 8),
  ],
);

void main() {
  late _Editor editor;
  late _Score score;

  setUpAll(() {
    registerFallbackValue(_cmaj7);
    registerFallbackValue(const SetRest());
  });

  setUp(() {
    editor = _Editor();
    score = _Score();
    when(() => score.state).thenReturn(
      ScoreState(song: drumsAndTwoGuitars, path: 'f.gp', selectedTrackIndex: 1),
    );
    when(() => editor.chordPositions(any())).thenAnswer((invocation) async {
      final spec = invocation.positionalArguments.single as ChordSpec;
      return spec == _cmaj7
          ? _positions
          : const ChordPositions(name: 'Cm7', positions: []);
    });
    when(() => editor.command(any())).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    EditorState state, {
    Stream<ScoreState>? scores,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(240, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(editor, const Stream<EditorState>.empty(), initialState: state);
    if (scores != null) {
      whenListen(
        score,
        scores,
        initialState: ScoreState(
          song: drumsAndTwoGuitars,
          path: 'f.gp',
          selectedTrackIndex: 1,
        ),
      );
    }
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
              BlocProvider<EditorCubit>.value(value: editor),
              BlocProvider<ScoreCubit>.value(value: score),
            ],
            child: const SingleChildScrollView(child: ChordPicker()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(InkWell, label).first);
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byKey(const Key('chord-key-selected')),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('building Cmaj7 shows its positions', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tapKey(tester, 'C');
    await tapKey(tester, 'maj7');

    verify(() => editor.chordPositions(_cmaj7)).called(1);
    expect(find.text('Cmaj7'), findsOneWidget);
    expect(find.byType(ChordDiagram), findsNWidgets(3));
    for (final label in ['Open', 'Fret 3', 'Fret 8']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping a position writes it', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tapKey(tester, 'C');
    await tapKey(tester, 'maj7');
    await tester.tap(find.text('Fret 3'));
    await tester.pump();

    verify(() => editor.command(const SetChord(_cmaj7, [-1, 3, 5, 4, 5, 3])))
        .called(1);
  });

  testWidgets("the cursor's chord shows as built", (tester) async {
    await pump(
      tester,
      const EditorState(
        position: _at,
        chordName: 'Cmaj7',
        chordSpec: _cmaj7,
        beatFrets: [-1, 3, 5, 4, 5, 3],
      ),
    );
    await tester.pumpAndSettle();

    expect(selected(tester, 'C'), isTrue);
    expect(selected(tester, 'maj7'), isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('position-selected')),
        matching: find.text('Fret 3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets("another file's chord name shows as text", (tester) async {
    await pump(tester, const EditorState(position: _at, chordName: 'N.C.'));
    expect(find.text('N.C.'), findsOneWidget);
    expect(selected(tester, 'C'), isFalse);
    verifyNever(() => editor.chordPositions(any()));
  });

  testWidgets("a late reply never replaces a newer chord's positions", (
    tester,
  ) async {
    final late = Completer<ChordPositions?>();
    when(() => editor.chordPositions(_cmaj7)).thenAnswer((_) => late.future);
    await pump(tester, const EditorState(position: _at));
    await tapKey(tester, 'C');
    await tapKey(tester, 'maj7');
    await tapKey(tester, 'm7');
    late.complete(_positions);
    await tester.pumpAndSettle();

    expect(find.text('Cm7'), findsOneWidget);
    expect(find.text('Cmaj7'), findsNothing);
    expect(find.byType(ChordDiagram), findsNothing);
    verify(() => editor.chordPositions(_cm7)).called(1);
  });

  testWidgets('a chord with no position says so', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tapKey(tester, 'C');
    await tapKey(tester, 'm7');
    expect(find.text('No playable position in this tuning'), findsOneWidget);
  });

  testWidgets('clashing additions replace each other', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tapKey(tester, '♭9');
    await tapKey(tester, '9');
    expect(selected(tester, '9'), isTrue);
    expect(selected(tester, '♭9'), isFalse);
  });

  testWidgets('the picker is off without a cursor', (tester) async {
    await pump(tester, const EditorState());
    await tester.tap(find.text('C'), warnIfMissed: false);
    await tester.pump();
    expect(selected(tester, 'C'), isFalse);
  });

  testWidgets("the last chord's positions never show while a new one loads", (
    tester,
  ) async {
    when(() => editor.chordPositions(_cm7))
        .thenAnswer((_) => Completer<ChordPositions?>().future);
    await pump(tester, const EditorState(position: _at));
    await tapKey(tester, 'C');
    await tapKey(tester, 'maj7');
    expect(find.byType(ChordDiagram), findsNWidgets(3));

    await tester.tap(find.widgetWithText(InkWell, 'm7').first);
    await tester.pump();
    expect(find.byType(ChordDiagram), findsNothing);
    expect(find.text('Cmaj7'), findsNothing);
  });

  testWidgets("a new tuning asks for the chord's positions again", (
    tester,
  ) async {
    final scores = StreamController<ScoreState>();
    addTearDown(scores.close);
    await pump(
      tester,
      const EditorState(
        position: _at,
        chordName: 'Cmaj7',
        chordSpec: _cmaj7,
        beatFrets: [-1, 3, 2, 0, 0, 0],
      ),
      scores: scores.stream,
    );
    await tester.pumpAndSettle();
    verify(() => editor.chordPositions(_cmaj7)).called(1);

    final guitar = drumsAndTwoGuitars.tracks[1];
    scores.add(
      ScoreState(
        song: SongSummary(
          title: drumsAndTwoGuitars.title,
          tracks: [
            drumsAndTwoGuitars.tracks[0],
            TrackSummary(
              index: guitar.index,
              name: guitar.name,
              kind: guitar.kind,
              stringCount: 6,
              tuning: const [62, 57, 53, 48, 43, 38],
              midiProgram: guitar.midiProgram,
            ),
            drumsAndTwoGuitars.tracks[2],
          ],
        ),
        path: 'f.gp',
        selectedTrackIndex: 1,
      ),
    );
    await tester.pumpAndSettle();
    verify(() => editor.chordPositions(_cmaj7)).called(1);
  });

  testWidgets('position tiles fit their label at large text', (tester) async {
    await pump(tester, const EditorState(position: _at), textScale: 1.6);
    await tapKey(tester, 'C');
    await tapKey(tester, 'maj7');
    expect(find.byType(ChordDiagram), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
