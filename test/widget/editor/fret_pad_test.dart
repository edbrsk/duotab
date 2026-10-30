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

  testWidgets('digits set the fret', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.text('7'));
    verify(() => editor.command(const SetFret(7))).called(1);
  });

  testWidgets('the arrows move the cursor', (tester) async {
    await pump(tester, const EditorState(position: _at));
    for (final (tooltip, direction) in [
      ('Next beat', 'right'),
      ('Previous beat', 'left'),
      ('String up', 'up'),
      ('String down', 'down'),
    ]) {
      await tester.tap(find.byTooltip(tooltip));
      verify(() => editor.command(Move(direction))).called(1);
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
