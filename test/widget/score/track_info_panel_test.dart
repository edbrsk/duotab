import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/chord_picker.dart';
import 'package:duoscore/features/editor/cursor_keys.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/editor/fret_pad.dart';
import 'package:duoscore/features/export/export_button.dart';
import 'package:duoscore/features/export/song_exporter.dart';
import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/tone.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:duoscore/features/score/track_info_panel.dart';
import 'package:duoscore/features/settings/settings_cubit.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Score extends MockCubit<ScoreState> implements ScoreCubit {}

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

class _Editor extends MockCubit<EditorState> implements EditorCubit {}

class _Settings extends MockCubit<AppSettings> implements SettingsCubit {}

const _song = SongSummary(
  title: 'Collateral',
  tracks: [
    TrackSummary(
      index: 0,
      name: 'Drums',
      kind: TrackKind.drums,
      stringCount: null,
      tuning: null,
      midiProgram: 0,
    ),
    TrackSummary(
      index: 1,
      name: 'Guitar 1',
      kind: TrackKind.guitar,
      stringCount: 6,
      tuning: [63, 58, 54, 49, 44, 39],
      midiProgram: 29,
    ),
  ],
);

void main() {
  late _Score score;
  late _Playback playback;
  late _Editor editor;
  late _Settings settings;

  setUpAll(() {
    registerFallbackValue(Tone.clean);
    registerFallbackValue(const SetRest());
    registerFallbackValue(PanelTab.track);
  });

  setUp(() {
    score = _Score();
    playback = _Playback();
    editor = _Editor();
    settings = _Settings();
    when(() => settings.setChordsShown(shown: any(named: 'shown')))
        .thenAnswer((_) async {});
    when(() => settings.setTrackDetailsFolded(folded: any(named: 'folded')))
        .thenAnswer((_) async {});
    when(() => settings.setInputFolded(folded: any(named: 'folded')))
        .thenAnswer((_) async {});
    when(() => settings.setPanelTab(any())).thenAnswer((_) async {});
    when(() => editor.state).thenReturn(const EditorState());
    when(() => playback.setTone(any(), any())).thenAnswer((_) async {});
    when(
      () => playback.setStaffView(
        any(),
        notation: any(named: 'notation'),
        tab: any(named: 'tab'),
        slash: any(named: 'slash'),
        numbered: any(named: 'numbered'),
      ),
    ).thenAnswer((_) async {});
    when(() => playback.state).thenReturn(
      const PlaybackState(
        practice: PracticeSettings(
          tracks: {
            0: TrackPractice(),
            1: TrackPractice(tone: Tone.overdrive),
          },
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    ScoreState state, {
    bool editable = true,
    bool chordsShown = false,
    bool trackDetailsFolded = false,
    bool inputFolded = false,
    PanelTab panelTab = PanelTab.track,
    double width = 220,
    double height = 626,
    Future<void> Function(ExportFormat, Rect)? onExport,
    double textScale = 1,
    bool scoreStreamed = false,
  }) async {
    when(() => settings.state).thenReturn(
      AppSettings(
        chordsShown: chordsShown,
        trackDetailsFolded: trackDetailsFolded,
        inputFolded: inputFolded,
        panelTab: panelTab,
      ),
    );
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (!scoreStreamed) when(() => score.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ScoreCubit>.value(value: score),
              BlocProvider<PlaybackCubit>.value(value: playback),
              BlocProvider<EditorCubit>.value(value: editor),
              BlocProvider<SettingsCubit>.value(value: settings),
            ],
            child: TrackInfoPanel(editable: editable, onExport: onExport),
          ),
        ),
      ),
    );
  }

  const drawn = ScoreState(song: _song, path: 'c.gp', selectedTrackIndex: 1);

  bool selectedView(String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byKey(const Key('view-selected')),
      )
      .evaluate()
      .isNotEmpty;

  Future<void> chooseTone(WidgetTester tester, String tone) async {
    await tester.ensureVisible(find.byType(DropdownButton<Tone>));
    await tester.tap(find.byType(DropdownButton<Tone>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tone).last);
    await tester.pumpAndSettle();
  }

  testWidgets("shows the drawn track's name, tuning and string count", (
    tester,
  ) async {
    await pump(tester, drawn);
    expect(find.text('Guitar 1'), findsOneWidget);
    expect(find.text('E♭ A♭ D♭ G♭ B♭ E♭ · 6 strings'), findsOneWidget);
    expect(find.text('Retune…'), findsOneWidget);
  });

  testWidgets('the switch labels stay on one line', (tester) async {
    await pump(tester, drawn, textScale: 1.3);
    for (final label in [
      'Frets',
      'Chords',
      'Song',
      'Track',
      'Standard',
      'Tab',
      'Slash',
      'Numbered',
    ]) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        text.size.height,
        text.getMinIntrinsicHeight(double.infinity),
        reason: label,
      );
    }
  });

  testWidgets('the panel switches between frets and chords', (tester) async {
    await pump(tester, drawn);
    expect(find.byType(FretPad), findsOneWidget);
    expect(find.byType(ChordPicker), findsNothing);
    await tester.tap(find.text('Chords'));
    verify(() => settings.setChordsShown(shown: true)).called(1);

    // A fresh tree: the mock setting doesn't emit its change.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, drawn, chordsShown: true, height: 2000);
    expect(find.byType(ChordPicker), findsOneWidget);
    expect(find.byType(FretPad), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pump(tester, drawn, editable: false);
    expect(find.text('Chords'), findsNothing);
  });

  testWidgets('a play-only panel has nothing that edits', (tester) async {
    await pump(tester, drawn, editable: false);

    expect(find.byType(FretPad), findsNothing);
    expect(find.byTooltip('Rename track'), findsNothing);
    expect(find.text('Retune…'), findsNothing);
    expect(find.text('Guitar 1'), findsOneWidget);
    expect(find.byTooltip('Numbered notation'), findsOneWidget);
    await tester.tap(find.byTooltip('Numbered notation'));
    verify(
      () => playback.setStaffView(
        1,
        notation: true,
        tab: true,
        slash: false,
        numbered: true,
      ),
    ).called(1);
    await chooseTone(tester, 'High gain');
    verify(() => playback.setTone(1, Tone.highGain)).called(1);
  });

  testWidgets("marks the track's tone and changes it", (tester) async {
    await pump(tester, drawn);
    final dropdown = tester.widget<DropdownButton<Tone>>(
      find.byType(DropdownButton<Tone>),
    );
    expect(dropdown.value, Tone.overdrive);
    expect(find.byType(RadioListTile<Tone>), findsNothing);
    await chooseTone(tester, 'High gain');
    verify(() => playback.setTone(1, Tone.highGain)).called(1);
  });

  testWidgets("the four views show the drawn track's choice", (tester) async {
    when(() => playback.state).thenReturn(
      const PlaybackState(
        practice: PracticeSettings(
          tracks: {1: TrackPractice(tone: Tone.overdrive, showSlash: true)},
        ),
      ),
    );
    await pump(tester, drawn);
    for (final (label, on) in [
      ('Standard', true),
      ('Tab', true),
      ('Slash', true),
      ('Numbered', false),
    ]) {
      expect(selectedView(label), on, reason: label);
    }
  });

  testWidgets('turning one off calls the cubit', (tester) async {
    await pump(tester, drawn);
    await tester.ensureVisible(find.text('Standard'));
    await tester.tap(find.text('Standard'));
    verify(
      () => playback.setStaffView(
        1,
        notation: false,
        tab: true,
        slash: false,
        numbered: false,
      ),
    ).called(1);
  });

  testWidgets("the last of Standard and Tab can't be turned off", (
    tester,
  ) async {
    when(() => playback.state).thenReturn(
      const PlaybackState(
        practice: PracticeSettings(
          tracks: {1: TrackPractice(tone: Tone.overdrive, showTab: false)},
        ),
      ),
    );
    await pump(tester, drawn);
    await tester.ensureVisible(find.text('Standard'));
    await tester.tap(find.text('Standard'));
    verifyNever(
      () => playback.setStaffView(
        any(),
        notation: any(named: 'notation'),
        tab: any(named: 'tab'),
        slash: any(named: 'slash'),
        numbered: any(named: 'numbered'),
      ),
    );
    await tester.tap(find.text('Slash'));
    verify(
      () => playback.setStaffView(
        1,
        notation: true,
        tab: false,
        slash: true,
        numbered: false,
      ),
    ).called(1);
  });

  testWidgets('is empty without a drawn track', (tester) async {
    await pump(tester, const ScoreState());
    expect(find.byType(DropdownButton<Tone>), findsNothing);
  });

  testWidgets('the track name renames the track', (tester) async {
    when(() => editor.renameTrack(any(), any())).thenAnswer((_) async {});
    await pump(tester, drawn);
    await tester.tap(find.byTooltip('Rename track'));
    await tester.pumpAndSettle();
    expect(find.text('Track name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Lead');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verify(() => editor.renameTrack(1, 'Lead')).called(1);
  });

  testWidgets('Retune opens the dialog and sends the chosen tuning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(951, 1400);
    when(() => editor.retune(any(), any(), octave: any(named: 'octave')))
        .thenAnswer((_) async {});
    await pump(tester, drawn);
    tester.view.physicalSize = const Size(951, 1400);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retune…'));
    await tester.pumpAndSettle();
    expect(find.text('Retune Guitar 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tuning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard E').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retune'));
    await tester.pumpAndSettle();
    verify(() => editor.retune(1, [64, 59, 55, 50, 45, 40])).called(1);
  });

  EditorState reported({
    int moved = 12,
    int unplayable = 3,
    int octave = 0,
    bool keepFrets = false,
  }) => EditorState(
    retune: RetuneReport(
      track: 1,
      tuning: const [64, 59, 55, 50, 45, 40],
      octave: octave,
      keepFrets: keepFrets,
      moved: moved,
      unplayable: unplayable,
    ),
  );

  testWidgets('the report shows the counts with Undo and the octave buttons', (
    tester,
  ) async {
    when(() => editor.state).thenReturn(reported());
    when(() => editor.undo()).thenAnswer((_) async {});
    when(() => editor.retuneOctave(any())).thenAnswer((_) async {});
    await pump(tester, drawn);
    expect(
      find.text("12 notes moved to another string, 3 can't be played"),
      findsOneWidget,
    );
    for (final label in ['Undo', 'Octave up', 'Octave down']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    verify(() => editor.undo()).called(1);
    verify(() => editor.retuneOctave(1)).called(1);
    verify(() => editor.retuneOctave(-1)).called(1);
  });

  testWidgets('Octave up is disabled at +2', (tester) async {
    when(() => editor.state).thenReturn(reported(octave: 2));
    await pump(tester, drawn);
    final up = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Octave up'),
    );
    final down = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Octave down'),
    );
    expect(up.onPressed, isNull);
    expect(down.onPressed, isNotNull);
  });

  testWidgets('a retune keeping frets offers Undo but no octave', (
    tester,
  ) async {
    when(() => editor.state).thenReturn(reported(keepFrets: true));
    await pump(tester, drawn);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Octave up'), findsNothing);
  });

  testWidgets('no report shows when both counts are zero', (tester) async {
    when(() => editor.state).thenReturn(reported(moved: 0, unplayable: 0));
    await pump(tester, drawn);
    expect(find.text('Octave up'), findsNothing);
  });

  bool onScreen(WidgetTester tester, Finder finder, double height) {
    final box = tester.getRect(finder);
    return box.top >= 0 && box.bottom <= height;
  }

  testWidgets('the arrows stay on screen below a long chord picker', (
    tester,
  ) async {
    when(() => editor.state).thenReturn(
      const EditorState(
        position: EditPosition(track: 1, bar: 0, voice: 0, beat: 0, string: 1),
      ),
    );
    when(() => editor.command(any())).thenAnswer((_) async {});
    await pump(tester, drawn, chordsShown: true);
    expect(find.byType(ChordPicker), findsOneWidget);
    expect(onScreen(tester, find.byType(CursorKeys), 626), isTrue);
    await tester.tap(find.byTooltip('Next beat'));
    verify(() => editor.command(const Move('right'))).called(1);
  });

  testWidgets('the frets pad shares the same arrows', (tester) async {
    await pump(tester, drawn);
    expect(find.byType(FretPad), findsOneWidget);
    expect(find.byType(CursorKeys), findsOneWidget);
    expect(onScreen(tester, find.byType(CursorKeys), 626), isTrue);
  });

  testWidgets('the track part takes at most 40% and scrolls on its own', (
    tester,
  ) async {
    await pump(tester, drawn);
    final part = tester.getSize(find.byKey(const Key('track-details')));
    expect(part.height, lessThanOrEqualTo(626 * 0.4));
    await tester.ensureVisible(find.byType(DropdownButton<Tone>));
    await tester.pump();
    expect(onScreen(tester, find.byType(CursorKeys), 626), isTrue);
  });

  testWidgets('a short track part is only as tall as its contents', (
    tester,
  ) async {
    await pump(tester, drawn, height: 2000);
    final part = tester.getSize(find.byKey(const Key('track-details')));
    expect(part.height, lessThan(2000 * 0.4));
  });

  testWidgets('a folded upper part shows only the tabs', (tester) async {
    await pump(tester, drawn, trackDetailsFolded: true);
    expect(find.text('Song'), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);
    expect(find.text('Guitar 1'), findsNothing);
    expect(find.textContaining('E♭ A♭'), findsNothing);
    expect(find.byType(DropdownButton<Tone>), findsNothing);
    expect(find.byType(FretPad), findsOneWidget);

    await tester.tap(find.byTooltip('Show details'));
    verify(() => settings.setTrackDetailsFolded(folded: false)).called(1);
  });

  testWidgets('a tab tap while folded unfolds on that tab', (tester) async {
    await pump(tester, drawn, trackDetailsFolded: true);
    await tester.tap(find.text('Song'));
    verify(() => settings.setPanelTab(PanelTab.song)).called(1);
    verify(() => settings.setTrackDetailsFolded(folded: false)).called(1);
  });

  testWidgets('a tab tap switches and is remembered', (tester) async {
    await pump(tester, drawn);
    await tester.tap(find.text('Song'));
    verify(() => settings.setPanelTab(PanelTab.song)).called(1);
    verifyNever(
      () => settings.setTrackDetailsFolded(folded: any(named: 'folded')),
    );
  });

  testWidgets('the Song tab hides the track', (tester) async {
    await pump(tester, drawn, panelTab: PanelTab.song);
    expect(find.text('Guitar 1'), findsNothing);
    expect(find.byType(DropdownButton<Tone>), findsNothing);
    expect(find.byType(FretPad), findsOneWidget);
  });

  testWidgets('a folded input part shows only its name', (tester) async {
    await pump(tester, drawn, inputFolded: true, chordsShown: true);
    expect(find.byType(ChordPicker), findsNothing);
    expect(find.byType(CursorKeys), findsNothing);
    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Chords'), findsNothing);
    expect(find.byType(DropdownButton<Tone>), findsOneWidget);

    await tester.tap(find.byTooltip('Show input'));
    verify(() => settings.setInputFolded(folded: false)).called(1);
  });

  testWidgets('each open part folds from its header', (tester) async {
    await pump(tester, drawn);
    await tester.tap(find.byTooltip('Hide details'));
    verify(() => settings.setTrackDetailsFolded(folded: true)).called(1);
    await tester.tap(find.byTooltip('Hide input'));
    verify(() => settings.setInputFolded(folded: true)).called(1);
  });

  testWidgets('a play-only panel is one part without arrows', (tester) async {
    await pump(tester, drawn, editable: false);
    expect(find.byType(CursorKeys), findsNothing);
    expect(find.byTooltip('Hide details'), findsNothing);
    expect(find.text('Song'), findsOneWidget);
  });

  testWidgets('both part headers use the same text size', (tester) async {
    await pump(tester, drawn, trackDetailsFolded: true, inputFolded: true);
    final tab = tester.renderObject<RenderParagraph>(find.text('Track'));
    final input = tester.renderObject<RenderParagraph>(find.text('Input'));
    expect(input.text.style?.fontSize, tab.text.style?.fontSize);
  });

  const withArtist = ScoreState(
    song: SongSummary(
      title: 'Collateral',
      artist: 'Rabea',
      tracks: [
        TrackSummary(
          index: 1,
          name: 'Guitar 1',
          kind: TrackKind.guitar,
          stringCount: 6,
          tuning: [63, 58, 54, 49, 44, 39],
          midiProgram: 29,
        ),
      ],
    ),
    path: 'c.gp',
    selectedTrackIndex: 1,
  );
  final title = find.descendant(
    of: find.byKey(const Key('song-title')),
    matching: find.byType(TextField),
  );
  final artist = find.descendant(
    of: find.byKey(const Key('song-artist')),
    matching: find.byType(TextField),
  );
  String fieldText(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  group('Song tab', () {
    setUp(() {
      when(() => editor.setTitle(any())).thenAnswer((_) async {});
      when(() => editor.setArtist(any())).thenAnswer((_) async {});
    });

    testWidgets('shows the title and artist in fields', (tester) async {
      await pump(tester, withArtist, panelTab: PanelTab.song);
      expect(fieldText(tester, title), 'Collateral');
      expect(fieldText(tester, artist), 'Rabea');
    });

    testWidgets('a submitted title is saved', (tester) async {
      await pump(tester, withArtist, panelTab: PanelTab.song);
      await tester.enterText(title, '  Riff ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verify(() => editor.setTitle('Riff')).called(1);
    });

    testWidgets('the artist is saved when the field loses focus', (
      tester,
    ) async {
      await pump(tester, withArtist, panelTab: PanelTab.song);
      await tester.enterText(artist, 'Rabea Massaad');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      verify(() => editor.setArtist('Rabea Massaad')).called(1);
    });

    testWidgets('a field left unchanged saves nothing', (tester) async {
      await pump(tester, drawn, panelTab: PanelTab.song);
      await tester.tap(title);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(artist);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verifyNever(() => editor.setTitle(any()));
      verifyNever(() => editor.setArtist(any()));
    });

    testWidgets('an empty title is not saved and comes back', (tester) async {
      await pump(tester, withArtist, panelTab: PanelTab.song);
      await tester.enterText(title, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verifyNever(() => editor.setTitle(any()));
      expect(fieldText(tester, title), 'Collateral');
    });

    testWidgets('clearing the artist clears it', (tester) async {
      await pump(tester, withArtist, panelTab: PanelTab.song);
      await tester.enterText(artist, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verify(() => editor.setArtist('')).called(1);
    });

    testWidgets('a new summary refreshes a field not being edited', (
      tester,
    ) async {
      final states = StreamController<ScoreState>();
      addTearDown(states.close);
      whenListen(score, states.stream, initialState: withArtist);
      await pump(
        tester,
        withArtist,
        panelTab: PanelTab.song,
        scoreStreamed: true,
      );
      states.add(
        ScoreState(
          song: SongSummary(title: 'Undone', tracks: withArtist.song!.tracks),
          path: 'c.gp',
          selectedTrackIndex: 1,
        ),
      );
      await tester.pump();
      expect(fieldText(tester, title), 'Undone');
      expect(fieldText(tester, artist), '');
    });

    testWidgets('typing in progress is saved when the tab switches', (
      tester,
    ) async {
      await pump(tester, withArtist, panelTab: PanelTab.song);
      await tester.enterText(artist, 'Rabea Massaad');
      await pump(tester, withArtist);
      verify(() => editor.setArtist('Rabea Massaad')).called(1);
    });

    testWidgets('typing in progress never reaches another song', (
      tester,
    ) async {
      final states = StreamController<ScoreState>();
      addTearDown(states.close);
      whenListen(score, states.stream, initialState: withArtist);
      await pump(
        tester,
        withArtist,
        panelTab: PanelTab.song,
        scoreStreamed: true,
      );
      await tester.enterText(artist, 'Rabea Massaad');
      const other = ScoreState(song: _song, path: 'other.gp', openId: 1);
      when(() => score.state).thenReturn(other);
      states.add(other);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      verifyNever(() => editor.setArtist(any()));
    });

    testWidgets('typing survives the song moving to its own copy', (
      tester,
    ) async {
      final states = StreamController<ScoreState>();
      addTearDown(states.close);
      whenListen(score, states.stream, initialState: withArtist);
      await pump(
        tester,
        withArtist,
        panelTab: PanelTab.song,
        scoreStreamed: true,
      );
      await tester.enterText(artist, 'Rabea Massaad');
      final moved = ScoreState(
        song: withArtist.song,
        path: 'c (DuoScore).gp',
        selectedTrackIndex: 1,
      );
      when(() => score.state).thenReturn(moved);
      states.add(moved);
      await tester.pump();
      expect(fieldText(tester, artist), 'Rabea Massaad');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      verify(() => editor.setArtist('Rabea Massaad')).called(1);
    });

    testWidgets('export sits in the Song tab', (tester) async {
      ExportFormat? exported;
      await pump(
        tester,
        withArtist,
        panelTab: PanelTab.song,
        onExport: (format, _) async => exported = format,
      );
      final button = tester.widget<ExportButton>(find.byType(ExportButton));
      expect(button.canExportPdf, isTrue);
      await button.onExport(ExportFormat.gp, Rect.zero);
      expect(exported, ExportFormat.gp);
    });

    testWidgets('play-only, the song is text with export', (tester) async {
      await pump(
        tester,
        withArtist,
        editable: false,
        panelTab: PanelTab.song,
        onExport: (_, _) async {},
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Collateral'), findsOneWidget);
      expect(find.text('Rabea'), findsOneWidget);
      expect(find.byType(ExportButton), findsOneWidget);
    });

    for (final tab in PanelTab.values) {
      testWidgets(
        'play-only on the outer screen at large text fits (${tab.name})',
        (tester) async {
          await pump(
            tester,
            withArtist,
            editable: false,
            panelTab: tab,
            width: 350,
            textScale: 1.3,
            onExport: (_, _) async {},
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
