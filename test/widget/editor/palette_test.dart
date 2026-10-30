import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/editor/palette.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

const _at = EditPosition(track: 0, bar: 0, voice: 0, beat: 0, string: 1);

void main() {
  late _Editor editor;

  setUpAll(() {
    registerFallbackValue(const SetRest());
  });

  setUp(() {
    editor = _Editor();
    when(() => editor.command(any())).thenAnswer((_) async {});
    when(() => editor.chooseDuration(any())).thenAnswer((_) async {});
    when(() => editor.chooseDots(any())).thenAnswer((_) async {});
    when(() => editor.undo()).thenAnswer((_) async {});
    when(() => editor.redo()).thenAnswer((_) async {});
    when(() => editor.toggle(any())).thenAnswer((_) async {});
    when(() => editor.setDynamic(any())).thenAnswer((_) async {});
    when(() => editor.setTuplet(any())).thenAnswer((_) async {});
    when(() => editor.addGrace()).thenAnswer((_) async {});
    when(() => editor.setBend(any(), any())).thenAnswer((_) async {});
    when(() => editor.setTimeSignature(any(), any())).thenAnswer((_) async {});
    when(() => editor.setTempo(any())).thenAnswer((_) async {});
    when(() => editor.setKeySignature(any(), minor: any(named: 'minor')))
        .thenAnswer((_) async {});
    when(() => editor.setClef(any())).thenAnswer((_) async {});
    when(() => editor.insertBar()).thenAnswer((_) async {});
    when(() => editor.deleteBar()).thenAnswer((_) async {});
    when(() => editor.copyBars()).thenAnswer((_) async {});
    when(() => editor.pasteBars()).thenAnswer((_) async {});
    when(() => editor.toggleRepeatStart()).thenAnswer((_) async {});
    when(() => editor.setRepeatEnd(any())).thenAnswer((_) async {});
    when(() => editor.toggleEnding(any())).thenAnswer((_) async {});
    when(() => editor.toggleDirection(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, EditorState state) async {
    tester.view
      ..physicalSize = const Size(240, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => editor.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<EditorCubit>.value(
            value: editor,
            child: const Palette(),
          ),
        ),
      ),
    );
  }

  ChoiceChip chip(WidgetTester tester, String tooltip) =>
      tester.widget<ChoiceChip>(
        find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(ChoiceChip),
        ),
      );

  testWidgets('groups for voice, note value, rests and dots', (tester) async {
    await pump(tester, const EditorState());
    for (final heading in ['VOICE', 'NOTE VALUE', 'RESTS', 'DOTS']) {
      expect(find.text(heading), findsOneWidget);
    }
  });

  testWidgets('marks the chosen note value', (tester) async {
    await pump(tester, const EditorState(duration: 8));
    expect(chip(tester, 'Eighth note').selected, isTrue);
    expect(chip(tester, 'Quarter note').selected, isFalse);
  });

  testWidgets("a note value sets the beat's duration", (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.byTooltip('Quarter note'));
    verify(() => editor.chooseDuration(4)).called(1);
  });

  testWidgets('a rest sets the beat to a rest of that value', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.byTooltip('Eighth rest'));
    await tester.pump();
    verifyInOrder([
      () => editor.chooseDuration(8),
      () => editor.command(const SetRest()),
    ]);
  });

  testWidgets('dots toggle', (tester) async {
    await pump(tester, const EditorState(position: _at, dots: 1));
    await tester.tap(find.byTooltip('Dot'));
    verify(() => editor.chooseDots(0)).called(1);
    await tester.tap(find.byTooltip('Double dot'));
    verify(() => editor.chooseDots(2)).called(1);
  });

  testWidgets('voices select the voice', (tester) async {
    await pump(tester, const EditorState(position: _at));
    expect(chip(tester, 'Voice 1').selected, isTrue);
    await tester.tap(find.byTooltip('Voice 2'));
    verify(() => editor.command(const SelectVoice(1))).called(1);
  });

  testWidgets('voices and rests need a cursor', (tester) async {
    await pump(tester, const EditorState());
    await tester.tap(find.byTooltip('Voice 2'));
    await tester.tap(find.byTooltip('Eighth rest'));
    await tester.pump();
    verifyNever(() => editor.command(any()));
    verifyNever(() => editor.chooseDuration(any()));
  });

  testWidgets('undo and redo follow the history', (tester) async {
    await pump(tester, const EditorState(canRedo: true));
    final undo = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.undo),
        matching: find.byType(IconButton),
      ),
    );
    expect(undo.onPressed, isNull);
    await tester.tap(find.byTooltip('Redo'));
    verify(() => editor.redo()).called(1);
  });

  testWidgets('the glyphs are drawn with Bravura', (tester) async {
    await pump(tester, const EditorState());
    final glyph = tester.widget<Text>(
      find.descendant(
        of: find.byTooltip('Quarter note'),
        matching: find.byType(Text),
      ),
    );
    expect(glyph.style?.fontFamily, 'Bravura');
    expect(glyph.data, '');
  });

  testWidgets('shows every technique group', (tester) async {
    await pump(tester, const EditorState());
    for (final heading in [
      'ACCIDENTALS',
      'DYNAMICS',
      'GUITAR TECHNIQUES',
      'ARTICULATION',
    ]) {
      expect(find.text(heading), findsOneWidget);
    }
  });

  testWidgets('active techniques are selected', (tester) async {
    await pump(
      tester,
      const EditorState(
        position: _at,
        hasNote: true,
        techniques: {'palmMute', 'accent'},
      ),
    );
    expect(chip(tester, 'Palm mute').selected, isTrue);
    expect(chip(tester, 'Accent').selected, isTrue);
    expect(chip(tester, 'Slide').selected, isFalse);
  });

  testWidgets('a technique chip toggles it', (tester) async {
    await pump(tester, const EditorState(position: _at, hasNote: true));
    await tester.tap(find.byTooltip('Slide'));
    verify(() => editor.toggle('slide')).called(1);
  });

  testWidgets('the bend chip opens the bend menu', (tester) async {
    await pump(tester, const EditorState(position: _at, hasNote: true));
    await tester.tap(find.byTooltip('Bend'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bend and release'));
    verify(() => editor.setBend('bendRelease', 4)).called(1);
    await tester.tap(find.byTooltip('1½ tones'));
    verify(() => editor.setBend('bend', 6)).called(1);
  });

  testWidgets('the bend menu shows the bend at the cursor', (tester) async {
    await pump(
      tester,
      const EditorState(
        position: _at,
        hasNote: true,
        techniques: {'bend'},
        bendKind: 'prebend',
        bendAmount: 2,
      ),
    );
    expect(chip(tester, 'Bend').selected, isTrue);
    await tester.tap(find.byTooltip('Bend'));
    await tester.pumpAndSettle();
    expect(chip(tester, 'Pre-bend').selected, isTrue);
    expect(chip(tester, '½ tone').selected, isTrue);
    await tester.tap(find.byTooltip('1½ tones'));
    verify(() => editor.setBend('prebend', 6)).called(1);
    await tester.tap(find.text('Remove bend'));
    verify(() => editor.setBend(null, 2)).called(1);
  });

  testWidgets('note techniques need a note on the cursor string', (
    tester,
  ) async {
    await pump(tester, const EditorState(position: _at));
    expect(chip(tester, 'Palm mute').onSelected, isNull);
    expect(chip(tester, 'Tie').onSelected, isNull);
    expect(chip(tester, 'Tapping').onSelected, isNotNull);
  });

  testWidgets('technique chips need a cursor', (tester) async {
    await pump(tester, const EditorState(hasNote: true));
    for (final tooltip in ['Palm mute', 'Tapping', 'Forte', 'Triplet']) {
      expect(chip(tester, tooltip).onSelected, isNull, reason: tooltip);
    }
  });

  testWidgets('a dynamic chip sets it, and the current one is selected', (
    tester,
  ) async {
    await pump(tester, const EditorState(position: _at, dynamicMark: 'mf'));
    expect(chip(tester, 'Mezzo-forte').selected, isTrue);
    expect(chip(tester, 'Forte').selected, isFalse);
    await tester.tap(find.byTooltip('Fortissimo'));
    verify(() => editor.setDynamic('ff')).called(1);
  });

  testWidgets('tuplets toggle', (tester) async {
    await pump(tester, const EditorState(position: _at, tuplet: 3));
    expect(chip(tester, 'Triplet').selected, isTrue);
    await tester.tap(find.byTooltip('Triplet'));
    verify(() => editor.setTuplet(1)).called(1);
    await tester.tap(find.byTooltip('Quintuplet'));
    verify(() => editor.setTuplet(5)).called(1);
  });

  testWidgets('grace note adds a grace beat', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.byTooltip('Grace note'));
    verify(() => editor.addGrace()).called(1);
  });

  testWidgets('symbols are Bravura glyphs', (tester) async {
    await pump(tester, const EditorState());
    final text = tester.widget<Text>(
      find.descendant(of: find.byTooltip('Sharp'), matching: find.byType(Text)),
    );
    expect(text.data, '\u{E262}');
    expect(text.style!.fontFamily, 'Bravura');
  });

  testWidgets('shows the bar groups', (tester) async {
    await pump(tester, const EditorState());
    expect(find.text('BAR'), findsOneWidget);
    expect(find.text('BARS'), findsOneWidget);
  });

  testWidgets("bar chips show the bar's values", (tester) async {
    await pump(
      tester,
      const EditorState(
        position: _at,
        barNumerator: 6,
        barDenominator: 8,
        barKey: -3,
        barClef: 'bass',
        barTempo: 90,
      ),
    );
    expect(find.text('6/8'), findsOneWidget);
    expect(find.text('E♭'), findsOneWidget);
    expect(find.text('♩ = 90'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byTooltip('Clef'),
        matching: find.text('\u{E062}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('bar chips need a cursor', (tester) async {
    await pump(tester, const EditorState(canPaste: true));
    for (final tooltip in [
      'Clef',
      'Time signature',
      'Key signature',
      'Tempo marking',
      'Insert bar',
      'Delete bar',
      'Copy bars',
      'Paste bars',
    ]) {
      expect(chip(tester, tooltip).onSelected, isNull, reason: tooltip);
    }
  });

  testWidgets('paste needs a clipboard', (tester) async {
    await pump(tester, const EditorState(position: _at));
    expect(chip(tester, 'Paste bars').onSelected, isNull);
    expect(chip(tester, 'Copy bars').onSelected, isNotNull);
  });

  testWidgets('the bars chips send their commands', (tester) async {
    await pump(
      tester,
      const EditorState(position: _at, canPaste: true, barCount: 2),
    );
    await tester.tap(find.byTooltip('Insert bar'));
    await tester.tap(find.byTooltip('Delete bar'));
    await tester.tap(find.byTooltip('Copy bars'));
    await tester.tap(find.byTooltip('Paste bars'));
    verify(() => editor.insertBar()).called(1);
    verify(() => editor.deleteBar()).called(1);
    verify(() => editor.copyBars()).called(1);
    verify(() => editor.pasteBars()).called(1);
  });

  testWidgets('the structure chips need a cursor', (tester) async {
    await pump(tester, const EditorState());
    for (final tooltip in [
      'Repeat start',
      'Repeat end',
      'Alternate ending',
      'Directions',
    ]) {
      expect(chip(tester, tooltip).onSelected, isNull, reason: tooltip);
    }
  });

  testWidgets('repeat start toggles and shows its state', (tester) async {
    await pump(tester, const EditorState(position: _at, repeatStart: true));
    expect(chip(tester, 'Repeat start').selected, isTrue);
    await tester.tap(find.byTooltip('Repeat start'));
    verify(() => editor.toggleRepeatStart()).called(1);
  });

  testWidgets('delete bar is off for a one-bar song', (tester) async {
    await pump(tester, const EditorState(position: _at, barCount: 1));
    expect(chip(tester, 'Delete bar').onSelected, isNull);
  });

  testWidgets('delete bar is on for a song with more bars', (tester) async {
    await pump(tester, const EditorState(position: _at, barCount: 2));
    expect(chip(tester, 'Delete bar').onSelected, isNotNull);
  });
}
