import 'dart:async';

import 'package:duoscore/features/export/export_button.dart';
import 'package:duoscore/features/export/song_exporter.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exports = <(ExportFormat, Rect)>[];
  late Future<void> Function() answer;

  setUp(() {
    exports.clear();
    answer = () async {};
  });

  Future<void> pumpButton(WidgetTester tester, {bool canExportPdf = true}) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: ExportButton(
                canExportPdf: canExportPdf,
                onExport: (format, anchor) {
                  exports.add((format, anchor));
                  return answer();
                },
              ),
            ),
          ),
        ),
      );

  Future<void> choose(WidgetTester tester, String item) async {
    await tester.tap(find.byType(ExportButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pump();
  }

  testWidgets('it is a dropdown asking for a format, with no icon', (
    tester,
  ) async {
    await pumpButton(tester);
    expect(find.byType(DropdownButton<ExportFormat>), findsOneWidget);
    expect(find.text('Choose a format'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsNothing);
  });

  testWidgets('after an export it asks for a format again', (tester) async {
    await pumpButton(tester);
    await choose(tester, 'Guitar Pro file (.gp)');
    await tester.pumpAndSettle();
    expect(find.text('Choose a format'), findsOneWidget);
  });

  testWidgets('the menu offers .gp and PDF', (tester) async {
    await pumpButton(tester);
    await tester.tap(find.byType(ExportButton));
    await tester.pumpAndSettle();
    expect(find.text('Guitar Pro file (.gp)'), findsWidgets);
    expect(find.text('PDF'), findsWidgets);
  });

  testWidgets('PDF is disabled without a guitar track', (tester) async {
    await pumpButton(tester, canExportPdf: false);
    await choose(tester, 'PDF');
    expect(exports, isEmpty);
  });

  testWidgets("choosing a format exports with the button's rect", (
    tester,
  ) async {
    await pumpButton(tester);
    final rect = tester.getRect(find.byType(ExportButton));
    await choose(tester, 'Guitar Pro file (.gp)');
    await tester.pumpAndSettle();
    expect(exports, [(ExportFormat.gp, rect)]);
    expect(rect.isEmpty, isFalse);
  });

  testWidgets('the button is disabled while an export runs', (tester) async {
    final running = Completer<void>();
    answer = () => running.future;
    await pumpButton(tester);
    await choose(tester, 'PDF');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ExportButton));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Guitar Pro file (.gp)'), findsNothing);
    expect(exports, hasLength(1));

    running.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed export shows the error', (tester) async {
    answer = () async => throw Exception('no room');
    await pumpButton(tester);
    await choose(tester, 'Guitar Pro file (.gp)');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't export"), findsOneWidget);
  });
}
