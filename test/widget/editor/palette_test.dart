import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/editor/editor_cubit.dart';
import 'package:duotab/features/editor/palette.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

const _at = EditPosition(track: 0, bar: 0, voice: 0, beat: 0, string: 1);

void main() {
  late _Editor editor;

  setUpAll(() => registerFallbackValue(const SetRest()));

  setUp(() {
    editor = _Editor();
    when(() => editor.command(any())).thenAnswer((_) async {});
    when(() => editor.chooseDuration(any())).thenAnswer((_) async {});
    when(() => editor.chooseDots(any())).thenAnswer((_) async {});
    when(() => editor.undo()).thenAnswer((_) async {});
    when(() => editor.redo()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, EditorState state) async {
    tester.view
      ..physicalSize = const Size(240, 900)
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
}
