import 'package:duoscore/features/settings/licences_page.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(
      () => Stream.fromIterable([
        const LicenseEntryWithLineBreaks(['alphaTab'], 'MPL TEXT'),
        const LicenseEntryWithLineBreaks(['Bravura'], 'OFL TEXT'),
        const LicenseEntryWithLineBreaks(['alphaTab'], 'SECOND TEXT'),
      ]),
    );
  });

  tearDown(LicenseRegistry.reset);

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(382, 678)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LicencesPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists each package once, under the app logo', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('appLogo')), findsOneWidget);
    expect(find.text('alphaTab'), findsOneWidget);
    expect(find.text('Bravura'), findsOneWidget);
    expect(find.text('Powered by Flutter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a package shows all of its licences' text", (tester) async {
    await pump(tester);
    await tester.tap(find.text('alphaTab'));
    await tester.pumpAndSettle();
    expect(find.text('MPL TEXT'), findsOneWidget);
    expect(find.text('SECOND TEXT'), findsOneWidget);
    expect(find.text('OFL TEXT'), findsNothing);
  });
}
