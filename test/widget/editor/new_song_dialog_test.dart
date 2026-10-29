import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/editor/new_song_dialog.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Future<NewSongOptions?>> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(951, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Future<NewSongOptions?> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showDialog<NewSongOptions>(
              context: context,
              builder: (_) => const NewSongDialog(),
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

  Future<void> choose(WidgetTester tester, Key dropdown, String item) async {
    await tester.tap(find.byKey(dropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'creates with the chosen strings, tuning, tempo and time signature',
    (tester) async {
      final result = await open(tester);
      await tester.enterText(find.byKey(const Key('title')), 'Riff');
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      await choose(tester, const Key('tuning'), 'Standard A');
      await tester.enterText(find.byKey(const Key('tempo')), '140');
      await tester.pump();
      await choose(tester, const Key('timeSignature'), '6/8');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final options = (await result)!;
      expect(options.title, 'Riff');
      expect(options.tuning, [62, 57, 53, 48, 43, 38, 33]);
      expect(options.tempo, 140);
      expect([options.numerator, options.denominator], [6, 8]);
    },
  );

  testWidgets('a custom tuning sets each string', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byKey(const Key('title')), 'Low');
    await tester.pump();
    await choose(tester, const Key('tuning'), 'Custom');
    await choose(tester, const Key('string6'), 'D2');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect((await result)!.tuning.last, 38);
  });

  testWidgets('a custom time signature', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byKey(const Key('title')), 'Odd');
    await tester.pump();
    await choose(tester, const Key('timeSignature'), 'Custom');
    await choose(tester, const Key('numerator'), '11');
    await choose(tester, const Key('denominator'), '16');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final options = (await result)!;
    expect([options.numerator, options.denominator], [11, 16]);
  });

  testWidgets('Create needs a title', (tester) async {
    await open(tester);
    final create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(create.onPressed, isNull);
  });

  testWidgets('starts as 6 strings, Standard E, 120, 4/4', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byKey(const Key('title')), 'Default');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final options = (await result)!;
    expect(options.tuning, [64, 59, 55, 50, 45, 40]);
    expect(options.tempo, 120);
    expect([options.numerator, options.denominator], [4, 4]);
  });
}
