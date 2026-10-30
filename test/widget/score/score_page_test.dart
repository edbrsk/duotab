import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/editor/editor_cubit.dart';
import 'package:duotab/features/editor/fret_pad.dart';
import 'package:duotab/features/editor/palette.dart';
import 'package:duotab/features/playback/playback_cubit.dart';
import 'package:duotab/features/playback/transport_bar.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:duotab/features/score/score_page.dart';
import 'package:duotab/features/settings/settings_cubit.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../unit/features/score/score_test_data.dart';

class _Engine extends Mock implements EngineBridge {}

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

class _Settings extends MockCubit<AppSettings> implements SettingsCubit {}

void main() {
  late _Engine engine;
  late ScoreCubit cubit;
  late _Playback playback;
  late _Editor editor;
  late _Settings settings;

  setUp(() {
    engine = _Engine();
    when(() => engine.events)
        .thenAnswer((_) => const Stream<EngineEvent>.empty());
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
    when(() => engine.open('fixture.gp'))
        .thenAnswer((_) async => drumsAndTwoGuitars);
    when(() => engine.open('beat.gp')).thenAnswer((_) async => drumsOnly);
    cubit = ScoreCubit(engine: engine);
    playback = _Playback();
    editor = _Editor();
    when(() => editor.state).thenReturn(const EditorState());
    when(() => playback.state).thenReturn(const PlaybackState());
    settings = _Settings();
    when(() => settings.state).thenReturn(const AppSettings());
    when(
      () => settings.setTrackPanelCollapsed(collapsed: any(named: 'collapsed')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester, {double width = 890}) async {
    tester.view
      ..physicalSize = Size(width, 626)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider<PlaybackCubit>.value(value: playback),
            BlocProvider<EditorCubit>.value(value: editor),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: const ScorePage(engineView: Text('engine view')),
        ),
      ),
    );
  }

  testWidgets('the right panel shows the drawn track', (tester) async {
    await cubit.open('fixture.gp');
    await pumpPage(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('trackPanel')),
        matching: find.text('Guitar 1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the title changes it', (tester) async {
    when(() => editor.setTitle(any())).thenAnswer((_) async {});
    await cubit.open('fixture.gp');
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Change title'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      drumsAndTwoGuitars.title,
    );
    await tester.enterText(find.byType(TextField), 'Riff');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verify(() => editor.setTitle('Riff')).called(1);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('says when a song has no guitar track', (tester) async {
    await cubit.open('beat.gp');
    await pumpPage(tester);

    expect(find.text('This song has no guitar track'), findsOneWidget);
  });

  testWidgets('collapsing the track panel saves the choice', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Hide track panel'));
    verify(() => settings.setTrackPanelCollapsed(collapsed: true)).called(1);
  });

  testWidgets('editing is off when the window is narrow', (tester) async {
    await cubit.open('fixture.gp');
    await pumpPage(tester, width: 600);
    expect(find.byType(Palette), findsNothing);
    expect(find.byType(FretPad), findsNothing);
    expect(find.text('Make DuoTab wider to edit'), findsOneWidget);
  });

  testWidgets('shows the palette when a song is open', (tester) async {
    await cubit.open('fixture.gp');
    await pumpPage(tester);
    expect(find.byType(Palette), findsOneWidget);
  });

  testWidgets('hides the transport when no song is open', (tester) async {
    await pumpPage(tester);
    expect(find.byType(TransportBar), findsNothing);
  });

  testWidgets('asks to open a song when none is open', (tester) async {
    await pumpPage(tester);

    expect(find.text('Open a song from the library'), findsOneWidget);
    // The engine stays mounted even with nothing to show.
    expect(find.text('engine view', skipOffstage: false), findsOneWidget);
  });

  testWidgets('shows an error from the engine', (tester) async {
    when(
      () => engine.open('broken.gp5'),
    ).thenThrow(const EngineException('No compatible importer found for file'));
    await cubit.open('broken.gp5');
    await pumpPage(tester);

    expect(
      find.text(
        "Couldn't show this song: No compatible importer found for file",
      ),
      findsOneWidget,
    );
    expect(find.text('Open a song from the library'), findsNothing);
  });
}
