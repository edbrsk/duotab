import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/core/duo/vertical_bar_edge_provider.dart';
import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/editor/fret_pad.dart';
import 'package:duoscore/features/editor/palette.dart';
import 'package:duoscore/features/export/export_button.dart';
import 'package:duoscore/features/export/song_exporter.dart';
import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/playback/transport_bar.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:duoscore/features/score/score_page.dart';
import 'package:duoscore/features/settings/settings_cubit.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:duoscore/presentation/shell/app_destinations.dart';
import 'package:duoscore/presentation/shell/bar_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

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
    when(() => editor.failures).thenAnswer((_) => const Stream.empty());
    when(() => playback.state).thenReturn(const PlaybackState());
    settings = _Settings();
    when(() => settings.state).thenReturn(const AppSettings());
    when(
      () => settings.setTrackPanelCollapsed(collapsed: any(named: 'collapsed')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => cubit.close());

  Future<void> pumpPage(
    WidgetTester tester, {
    double width = 890,
    Future<void> Function(ExportFormat, Rect)? onExport,
    VerticalBarEdgeProvider? edge,
    BarActions? barActions,
    double rightPadding = 0,
  }) async {
    tester.view
      ..physicalSize = Size(width, 626)
      ..devicePixelRatio = 1
      ..padding = FakeViewPadding(right: rightPadding);
    addTearDown(tester.view.reset);
    Widget app = MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider<PlaybackCubit>.value(value: playback),
            BlocProvider<EditorCubit>.value(value: editor),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: ScorePage(
            engineView: const Text('engine view'),
            onExport: onExport,
          ),
        ),
      ),
    );
    if (barActions != null) {
      app = ChangeNotifierProvider.value(value: barActions, child: app);
    }
    if (edge != null) {
      app = ChangeNotifierProvider.value(value: edge, child: app);
    }
    await tester.pumpWidget(app);
  }

  group('play-only', () {
    const show = 'Show track panel';
    const hide = 'Hide track panel';
    final panel = find.byKey(const Key('playOnlyPanel'));

    testWidgets('the track panel button opens the panel over the page', (
      tester,
    ) async {
      await cubit.open('fixture.gp');
      await pumpPage(tester, width: 466);

      await tester.tap(find.byTooltip(show));
      await tester.pump();
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.byType(FretPad)),
        findsNothing,
      );

      await tester.tap(find.byTooltip(hide));
      await tester.pump();
      expect(panel, findsNothing);
    });

    testWidgets('with the vertical bar, the button goes to the bar', (
      tester,
    ) async {
      final edgeEvents = StreamController<dynamic>();
      final edge = VerticalBarEdgeProvider(edgeEvents: edgeEvents.stream);
      final barActions = BarActions();
      addTearDown(() async {
        edge.dispose();
        barActions.dispose();
        await edgeEvents.close();
      });
      edgeEvents.add('trailing');
      await cubit.open('fixture.gp');
      await pumpPage(
        tester,
        width: 466,
        rightPadding: 84,
        edge: edge,
        barActions: barActions,
      );
      await tester.pump();
      await tester.pump();

      var actions = barActions.of(AppTab.editor);
      expect(actions, hasLength(1));
      expect(actions.single.tooltip, show);
      expect(actions.single.icon, Icons.menu);
      expect(find.widgetWithIcon(IconButton, Icons.menu), findsNothing);

      actions.single.onPressed();
      await tester.pump();
      await tester.pump();
      expect(panel, findsOneWidget);
      actions = barActions.of(AppTab.editor);
      expect(actions.single.tooltip, hide);
      expect(actions.single.icon, Icons.close);
    });

    testWidgets('widening the window closes the play-only panel', (
      tester,
    ) async {
      await cubit.open('fixture.gp');
      await pumpPage(tester, width: 466);
      await tester.tap(find.byTooltip(show));
      await tester.pump();

      await pumpPage(tester);
      expect(panel, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('trackPanel')),
          matching: find.byType(FretPad),
        ),
        findsOneWidget,
      );

      await pumpPage(tester, width: 466);
      expect(panel, findsNothing);
    });

    testWidgets('no song, no track panel button', (tester) async {
      await pumpPage(tester, width: 466);
      expect(find.byTooltip(show), findsNothing);
    });

    testWidgets("the title can't be changed", (tester) async {
      await cubit.open('fixture.gp');
      await pumpPage(tester, width: 466);
      expect(find.byTooltip('Change title'), findsNothing);
      expect(find.text(drumsAndTwoGuitars.title), findsOneWidget);
    });

    testWidgets("a tap doesn't move the edit cursor", (tester) async {
      await cubit.open('fixture.gp');
      await pumpPage(tester, width: 466);
      verify(() => editor.placesOnTap = false).called(1);

      await pumpPage(tester);
      verify(() => editor.placesOnTap = true).called(1);
    });
  });

  testWidgets('the export button shows beside the title when a song is open', (
    tester,
  ) async {
    await pumpPage(tester, onExport: (_, _) async {});
    await tester.pump();
    expect(find.byType(ExportButton), findsNothing);

    await cubit.open('fixture.gp');
    await tester.pump();
    expect(find.byType(ExportButton), findsOneWidget);
  });

  testWidgets('a failed track edit says why', (tester) async {
    when(() => editor.failures)
        .thenAnswer((_) => Stream.value('no free MIDI channel'));
    await pumpPage(tester);
    await cubit.open('fixture.gp');
    await tester.pump();
    await tester.pump();
    expect(
      find.text('No MIDI channel is free for another track'),
      findsOneWidget,
    );
  });

  testWidgets('an opened song with unplayable notes says so once', (
    tester,
  ) async {
    when(() => engine.open('xml.musicxml')).thenAnswer(
      (_) async => SongSummary(
        title: 'Part',
        tracks: drumsAndTwoGuitars.tracks,
        unplayableNotes: 3,
      ),
    );
    await pumpPage(tester);
    await cubit.open('xml.musicxml');
    await tester.pump();
    const message =
        "3 notes can't be played in this tuning. They're marked in red.";
    expect(find.text(message), findsOneWidget);

    cubit.applyEdit(
      SongSummary(
        title: 'Part',
        tracks: drumsAndTwoGuitars.tracks,
        unplayableNotes: 3,
      ),
    );
    await tester.pump();
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('a long title beside the export button does not overflow', (
    tester,
  ) async {
    when(() => engine.open('long.gp')).thenAnswer(
      (_) async => SongSummary(
        title: 'A very long song title ' * 6,
        tracks: drumsAndTwoGuitars.tracks,
      ),
    );
    await pumpPage(tester, onExport: (_, _) async {});
    await cubit.open('long.gp');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ExportButton), findsOneWidget);
  });

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
    expect(find.text('Make DuoScore wider to edit'), findsOneWidget);
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
