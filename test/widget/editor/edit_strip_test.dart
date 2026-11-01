import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/cursor_keys.dart';
import 'package:duoscore/features/editor/edit_strip.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

void main() {
  late _Editor editor;

  setUp(() {
    editor = _Editor();
    when(() => editor.undo()).thenAnswer((_) async {});
    when(() => editor.redo()).thenAnswer((_) async {});
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
            child: const SizedBox(width: 224, child: EditStrip()),
          ),
        ),
      ),
    );
  }

  testWidgets('undo and redo follow the history, cursor or not', (
    tester,
  ) async {
    await pump(tester, const EditorState(canRedo: true));
    await tester.tap(find.byTooltip('Undo'), warnIfMissed: false);
    verifyNever(() => editor.undo());
    await tester.tap(find.byTooltip('Redo'));
    verify(() => editor.redo()).called(1);
  });

  testWidgets('undo and redo sit above the arrows', (tester) async {
    await pump(
      tester,
      const EditorState(
        canUndo: true,
        position: EditPosition(track: 0, bar: 0, voice: 0, beat: 0, string: 1),
      ),
    );
    expect(find.byType(CursorKeys), findsOneWidget);
    final undo = tester.getRect(find.byTooltip('Undo'));
    final next = tester.getRect(find.byTooltip('Next beat'));
    expect(undo.bottom, lessThanOrEqualTo(next.top));
    await tester.tap(find.byTooltip('Undo'));
    verify(() => editor.undo()).called(1);
  });

  testWidgets('undo and redo are at least 44 points square', (tester) async {
    await pump(tester, const EditorState(canUndo: true));
    final key = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.undo),
        matching: find.byType(InkWell),
      ),
    );
    expect(key.width, greaterThanOrEqualTo(44));
    expect(key.height, greaterThanOrEqualTo(44));
  });
}
