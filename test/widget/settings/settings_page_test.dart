import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/features/playback/tone.dart';
import 'package:duoscore/features/settings/licences_page.dart';
import 'package:duoscore/features/settings/settings_cubit.dart';
import 'package:duoscore/features/settings/settings_page.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends MockCubit<AppSettings> implements SettingsCubit {}

void main() {
  late _Settings settings;

  setUp(() {
    settings = _Settings();
    when(() => settings.state).thenReturn(const AppSettings());
    when(() => settings.setCountIn(on: any(named: 'on')))
        .thenAnswer((_) async {});
    when(() => settings.setMetronome(on: any(named: 'on')))
        .thenAnswer((_) async {});
    when(() => settings.setDefaultTone(any())).thenAnswer((_) async {});
  });

  setUpAll(() => registerFallbackValue(Tone.clean));

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(890, 1200),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<SettingsCubit>.value(
            value: settings,
            child: const SettingsPage(),
          ),
        ),
      ),
    );
  }

  testWidgets('toggles count-in and metronome', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Count-in'));
    verify(() => settings.setCountIn(on: true)).called(1);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Metronome'));
    verify(() => settings.setMetronome(on: true)).called(1);
  });

  testWidgets('chooses the default tone from a dropdown', (tester) async {
    await pump(tester);
    expect(find.byType(RadioListTile<Tone>), findsNothing);
    expect(find.text('Clean'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<Tone>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High gain').last);
    await tester.pumpAndSettle();
    verify(() => settings.setDefaultTone(Tone.highGain)).called(1);
  });

  testWidgets("the app's name heads the options, with no logo", (tester) async {
    await pump(tester);
    final name = find.text('DuoScore');
    expect(tester.widget<Text>(name).style?.fontFamily, 'Didot');
    expect(tester.getRect(name).center.dx, closeTo(890 / 2, 1));
    expect(
      tester.getRect(name).bottom,
      lessThan(tester.getRect(find.text('Count-in')).top),
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('opens the licence screen', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicencesPage), findsOneWidget);
  });

  testWidgets('fits beside the vertical bar on the outer screen', (
    tester,
  ) async {
    await pump(tester, size: const Size(382, 678));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicencesPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
