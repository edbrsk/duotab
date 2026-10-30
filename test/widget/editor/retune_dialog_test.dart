import 'package:duoscore/features/editor/retune_dialog.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Future<RetuneChoice?>> open(
    WidgetTester tester,
    List<int> tuning,
  ) async {
    tester.view
      ..physicalSize = const Size(951, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Future<RetuneChoice?> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showDialog<RetuneChoice>(
              context: context,
              builder: (_) => RetuneDialog(trackName: 'Lead', tuning: tuning),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets("the dialog starts at the track's tuning", (tester) async {
    await open(tester, const [62, 57, 53, 48, 43, 38]);
    expect(find.text('Retune Lead'), findsOneWidget);
    expect(
      find.text('Every note keeps its pitch; frets move.'),
      findsOneWidget,
    );
    expect(find.text('Standard D'), findsOneWidget);
    expect(find.byKey(const Key('string1')), findsNothing);
  });

  testWidgets('a custom tuning starts as Custom with its notes', (
    tester,
  ) async {
    await open(tester, const [62, 59, 55, 50, 45, 40]);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.byKey(const Key('string1')), findsOneWidget);
  });

  testWidgets('Retune pops the chosen tuning and Cancel pops null', (
    tester,
  ) async {
    var result = await open(tester, const [62, 57, 53, 48, 43, 38]);
    await tester.tap(find.byKey(const Key('tuning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard E').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retune'));
    await tester.pumpAndSettle();
    expect((await result)!.tuning, [64, 59, 55, 50, 45, 40]);
    expect((await result)!.keepFrets, isFalse);

    result = await open(tester, const [62, 57, 53, 48, 43, 38]);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('a tuning the fields cannot show retunes to what they show', (
    tester,
  ) async {
    final result = await open(tester, const [43, 38, 33, 28]);
    expect(find.text('Standard E'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retune'));
    await tester.pumpAndSettle();
    expect((await result)!.tuning, [64, 59, 55, 50, 45, 40]);
  });

  testWidgets('Keep the frets changes the hint and is popped', (tester) async {
    final result = await open(tester, const [63, 58, 54, 49, 44, 39]);
    await tester.tap(find.text('Keep the frets'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Every note keeps its string and fret, and sounds in the new tuning.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('tuning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard E').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retune'));
    await tester.pumpAndSettle();
    expect((await result)!.keepFrets, isTrue);
    expect((await result)!.tuning, [64, 59, 55, 50, 45, 40]);
  });
}
