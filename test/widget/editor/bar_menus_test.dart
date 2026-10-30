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

  setUpAll(() => registerFallbackValue(const SetRest()));

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

  testWidgets('a time signature preset sets it', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.byTooltip('Time signature'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6/8'));
    verify(() => editor.setTimeSignature(6, 8)).called(1);
  });

  testWidgets('the custom time signature steps the numerator', (tester) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.byTooltip('Time signature'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More beats'));
    verify(() => editor.setTimeSignature(5, 4)).called(1);
    await tester.tap(find.byTooltip('Fewer beats'));
    verify(() => editor.setTimeSignature(3, 4)).called(1);
    await tester.tap(find.byTooltip('Beat value 8'));
    verify(() => editor.setTimeSignature(4, 8)).called(1);
  });

  testWidgets('a key chip sets the key, and minor names follow the toggle', (
    tester,
  ) async {
    await pump(tester, const EditorState(position: _at));
    await tester.tap(find.byTooltip('Key signature'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E♭'));
    verify(() => editor.setKeySignature(-3, minor: false)).called(1);
    await tester.tap(find.text('Minor'));
    await tester.pump();
    await tester.tap(find.text('Cm'));
    verify(() => editor.setKeySignature(-3, minor: true)).called(1);
  });

  testWidgets('a clef chip sets it', (tester) async {
    await pump(tester, const EditorState(position: _at, barClef: 'treble'));
    await tester.tap(find.byTooltip('Clef'));
    await tester.pumpAndSettle();
    expect(chip(tester, 'Treble clef').selected, isTrue);
    await tester.tap(find.byTooltip('Bass clef'));
    verify(() => editor.setClef('bass')).called(1);
  });

  testWidgets('the tempo dialog sets, refuses and removes', (tester) async {
    const bar1 = EditPosition(track: 0, bar: 1, voice: 0, beat: 0, string: 1);
    await pump(tester, const EditorState(position: bar1, barTempoChange: true));
    await tester.tap(find.byTooltip('Tempo marking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Set'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '140');
    await tester.pump();
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    verify(() => editor.setTempo(140)).called(1);
    await tester.tap(find.byTooltip('Tempo marking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove tempo change'));
    await tester.pumpAndSettle();
    verify(() => editor.setTempo(null)).called(1);
  });

  testWidgets('the first bar keeps its tempo', (tester) async {
    await pump(tester, const EditorState(position: _at, barTempoChange: true));
    await tester.tap(find.byTooltip('Tempo marking'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Remove tempo change'),
          )
          .onPressed,
      isNull,
    );
  });
}
