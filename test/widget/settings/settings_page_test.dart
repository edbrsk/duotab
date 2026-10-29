import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/features/playback/tone.dart';
import 'package:duotab/features/settings/settings_cubit.dart';
import 'package:duotab/features/settings/settings_page.dart';
import 'package:duotab/l10n/app_localizations.dart';
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

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(890, 1200)
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

  testWidgets('chooses the default tone', (tester) async {
    await pump(tester);
    await tester.tap(find.text('High gain'));
    verify(() => settings.setDefaultTone(Tone.highGain)).called(1);
  });

  testWidgets('opens the licence screen', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
