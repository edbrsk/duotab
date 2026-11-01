import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/editor/fret_pad.dart';
import 'package:duoscore/l10n/app_localizations.dart';
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
  });

  Future<void> pump(WidgetTester tester, EditorState state) async {
    when(() => editor.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<EditorCubit>.value(
            value: editor,
            child: const SizedBox(width: 140, child: FretPad()),
          ),
        ),
      ),
    );
  }

  testWidgets('two quick digits make one fret on one undo step', (
    tester,
  ) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    verify(() => editor.command(const SetFret(1))).called(1);
    verify(() => editor.command(const SetFret(12, combine: true))).called(1);
  });

  testWidgets('a cursor move between digits splits them', (tester) async {
    final states = StreamController<EditorState>();
    addTearDown(states.close);
    whenListen(
      editor,
      states.stream,
      initialState: const EditorState(position: _at),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<EditorCubit>.value(
            value: editor,
            child: const SizedBox(width: 140, child: FretPad()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('1'));
    states.add(
      const EditorState(
        position: EditPosition(track: 0, bar: 0, voice: 0, beat: 1, string: 1),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('2'));
    verify(() => editor.command(const SetFret(2))).called(1);
    verifyNever(() => editor.command(const SetFret(12, combine: true)));
  });

  testWidgets('digits set the fret', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.text('7'));
    verify(() => editor.command(const SetFret(7))).called(1);
  });

  testWidgets('the arrows live outside the pad', (tester) async {
    await pump(tester, const EditorState(position: _at));
    for (final tooltip in [
      'Next beat',
      'Previous beat',
      'String up',
      'String down',
    ]) {
      expect(find.byTooltip(tooltip), findsNothing);
    }
  });

  testWidgets('delete removes the note', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.byTooltip('Delete note'));
    verify(() => editor.command(const DeleteNote())).called(1);
  });

  testWidgets('the pad is disabled without a cursor', (tester) async {
    await pump(tester, const EditorState());
    await tester.tap(find.text('7'));
    verifyNever(() => editor.command(any()));
  });

  testWidgets('every key is at least 44 points square in a 140-point panel', (
    tester,
  ) async {
    await pump(tester, const EditorState(position: _at));
    final key = tester.getSize(
      find.ancestor(of: find.text('5'), matching: find.byType(InkWell)),
    );
    expect(key.width, greaterThanOrEqualTo(44));
    expect(key.height, greaterThanOrEqualTo(44));
  });
}
