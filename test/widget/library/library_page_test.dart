import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/export/song_exporter.dart';
import 'package:duoscore/features/library/library_cubit.dart';
import 'package:duoscore/features/library/library_page.dart';
import 'package:duoscore/features/library/song_files.dart';
import 'package:duoscore/features/library/song_list_entry.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Library extends MockCubit<LibraryState> implements LibraryCubit {}

void main() {
  Future<_Library> pumpPage(
    WidgetTester tester,
    LibraryState state, {
    void Function(String path)? onOpen,
    Future<void> Function(NewSongOptions options)? onNewSong,
    Future<void> Function(String path)? onDelete,
    Future<NameProblem?> Function(String path, String name, {String? original})?
    onRename,
    Future<void> Function()? onImport,
    Future<void> Function(
      SongListEntry entry,
      ExportFormat format,
      Rect anchor,
    )?
    onExport,
    Stream<String>? importFailures,
  }) async {
    final library = _Library();
    whenListen(
      library,
      const Stream<LibraryState>.empty(),
      initialState: state,
    );
    when(library.refresh).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // SnackBars need a Scaffold, which the app shell gives the page.
        home: Scaffold(
          body: BlocProvider<LibraryCubit>.value(
            value: library,
            child: LibraryPage(
              onOpen: onOpen ?? (_) {},
              onNewSong: onNewSong ?? (_) async {},
              onDelete: onDelete ?? (_) async {},
              onRename: onRename ?? (_, _, {original}) async => null,
              onImport: onImport ?? () async {},
              onExport: onExport ?? (_, _, _) async {},
              importFailures: importFailures,
            ),
          ),
        ),
      ),
    );
    return library;
  }

  testWidgets('shows title, tuning and string count', (tester) async {
    String? opened;
    await pumpPage(
      tester,
      const LibraryState(
        loading: false,
        songs: [
          SongListEntry(
            path: '07 Collateral Damage.gp',
            name: '07 Collateral Damage',
            tuningLabel: 'E♭ A♭ D♭ G♭ B♭ E♭',
            stringCount: 6,
            readable: true,
          ),
          SongListEntry(
            path: 'broken.gp5',
            name: 'broken',
            tuningLabel: null,
            stringCount: null,
            readable: false,
          ),
        ],
      ),
      onOpen: (path) => opened = path,
    );

    expect(find.text('07 Collateral Damage'), findsOneWidget);
    expect(find.textContaining('E♭ A♭ D♭ G♭ B♭ E♭'), findsOneWidget);
    expect(find.textContaining('6 strings'), findsOneWidget);
    expect(find.text("Can't open this file"), findsOneWidget);

    await tester.tap(find.text('07 Collateral Damage'));
    expect(opened, '07 Collateral Damage.gp');
  });

  testWidgets('shows the empty-library hint', (tester) async {
    await pumpPage(tester, const LibraryState(loading: false, songs: []));

    expect(
      find.text('Tap Import to add Guitar Pro or MusicXML files'),
      findsOneWidget,
    );
  });

  testWidgets('New song opens the dialog and creates the song', (tester) async {
    tester.view
      ..physicalSize = const Size(951, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    NewSongOptions? created;
    await pumpPage(
      tester,
      const LibraryState(loading: false, songs: []),
      onNewSong: (options) async => created = options,
    );

    await tester.tap(find.text('New song'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('title')), 'Riff');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(created?.title, 'Riff');
  });

  const riff = LibraryState(
    loading: false,
    songs: [
      SongListEntry(
        path: 'Riff.gp',
        name: 'Riff',
        tuningLabel: 'E A D G B E',
        stringCount: 6,
        readable: true,
      ),
    ],
  );

  Future<void> chooseFromMenu(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('Song actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('delete asks first, then deletes and refreshes', (tester) async {
    String? deleted;
    final library = await pumpPage(
      tester,
      riff,
      onDelete: (path) async => deleted = path,
    );
    await chooseFromMenu(tester, 'Delete');
    expect(find.text('Delete "Riff"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 'Riff.gp');
    verify(library.refresh).called(2);
  });

  testWidgets('cancelling the delete keeps the song', (tester) async {
    String? deleted;
    await pumpPage(tester, riff, onDelete: (path) async => deleted = path);
    await chooseFromMenu(tester, 'Delete');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, isNull);
  });

  testWidgets('rename asks for the new name', (tester) async {
    (String, String)? renamed;
    await pumpPage(
      tester,
      riff,
      onRename: (path, name, {original}) async {
        renamed = (path, name);
        return null;
      },
    );
    await chooseFromMenu(tester, 'Rename');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Riff',
    );
    await tester.enterText(find.byType(TextField), 'Riff 2');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(renamed, ('Riff.gp', 'Riff 2'));
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('rename says why a name is refused', (tester) async {
    await pumpPage(
      tester,
      riff,
      onRename: (_, _, {original}) async => NameProblem.taken,
    );
    await chooseFromMenu(tester, 'Rename');
    await tester.enterText(find.byType(TextField), 'Other');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Another song already has this name'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Import opens the Files picker', (tester) async {
    var imports = 0;
    await pumpPage(
      tester,
      const LibraryState(loading: false, songs: []),
      onImport: () async => imports++,
    );
    await tester.tap(find.text('Import'));
    expect(imports, 1);
  });

  const edited = LibraryState(
    loading: false,
    songs: [
      SongListEntry(
        path: 'a (DuoScore).gp',
        name: 'a',
        tuningLabel: 'E A D G B E',
        stringCount: 6,
        readable: true,
        original: 'a.gp',
      ),
    ],
  );

  testWidgets('an edited song is tagged and reverts after asking', (
    tester,
  ) async {
    final deleted = <String>[];
    await pumpPage(tester, edited, onDelete: (path) async => deleted.add(path));
    expect(find.text('Edited · E A D G B E · 6 strings'), findsOneWidget);
    await chooseFromMenu(tester, 'Revert to original');
    expect(find.text('Revert "a"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Revert'));
    await tester.pumpAndSettle();
    expect(deleted, ['a (DuoScore).gp']);
  });

  testWidgets('deleting an edited song deletes its original too', (
    tester,
  ) async {
    final deleted = <String>[];
    await pumpPage(tester, edited, onDelete: (path) async => deleted.add(path));
    await chooseFromMenu(tester, 'Delete');
    expect(
      find.text(
        "The original file and your edited copy are removed from this iPhone and can't be recovered.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleted, ['a (DuoScore).gp', 'a.gp']);
  });

  testWidgets('deleting one of two copies keeps the original', (tester) async {
    final deleted = <String>[];
    await pumpPage(
      tester,
      const LibraryState(
        loading: false,
        songs: [
          SongListEntry(
            path: 'a (DuoScore).gp',
            name: 'a',
            tuningLabel: null,
            stringCount: 6,
            readable: true,
            original: 'a.gp',
          ),
          SongListEntry(
            path: 'a (DuoScore) (2).gp',
            name: 'a (DuoScore) (2)',
            tuningLabel: null,
            stringCount: 6,
            readable: true,
            original: 'a.gp',
          ),
        ],
      ),
      onDelete: (path) async => deleted.add(path),
    );
    await tester.tap(find.byTooltip('Song actions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(
      find.text("The file is removed from this iPhone and can't be recovered."),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleted, ['a (DuoScore) (2).gp']);
  });

  testWidgets('a delete that fails says so and still refreshes', (
    tester,
  ) async {
    final library = await pumpPage(
      tester,
      riff,
      onDelete: (_) async => throw const FileSystemException('locked'),
    );
    await chooseFromMenu(tester, 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't change the song"), findsOneWidget);
    verify(library.refresh).called(2);
  });

  testWidgets('a rename that fails says so and still refreshes', (
    tester,
  ) async {
    final library = await pumpPage(
      tester,
      riff,
      onRename: (_, _, {original}) async =>
          throw const FileSystemException('locked'),
    );
    await chooseFromMenu(tester, 'Rename');
    await tester.enterText(find.byType(TextField), 'Other');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining("Couldn't change the song"), findsOneWidget);
    verify(library.refresh).called(2);
  });

  testWidgets('renaming an edited song passes its original', (tester) async {
    String? passed;
    await pumpPage(
      tester,
      edited,
      onRename: (path, name, {original}) async {
        passed = original;
        return null;
      },
    );
    await chooseFromMenu(tester, 'Rename');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(passed, 'a.gp');
  });

  testWidgets('a song that was never edited offers no Revert', (tester) async {
    await pumpPage(tester, riff);
    await tester.tap(find.byTooltip('Song actions'));
    await tester.pumpAndSettle();
    expect(find.text('Revert to original'), findsNothing);
  });

  testWidgets("Export shares the song from the menu's button", (tester) async {
    final exports = <(String, ExportFormat, Rect)>[];
    await pumpPage(
      tester,
      edited,
      onExport: (entry, format, anchor) async =>
          exports.add((entry.path, format, anchor)),
    );
    final button = tester.getRect(find.byTooltip('Song actions'));
    await chooseFromMenu(tester, 'Export as PDF');
    await chooseFromMenu(tester, 'Export as .gp');
    expect(exports, [
      ('a (DuoScore).gp', ExportFormat.pdf, button),
      ('a (DuoScore).gp', ExportFormat.gp, button),
    ]);
  });

  testWidgets('a song without a guitar track offers no PDF', (tester) async {
    final exports = <ExportFormat>[];
    await pumpPage(
      tester,
      const LibraryState(
        loading: false,
        songs: [
          SongListEntry(
            path: 'beat.gp',
            name: 'beat',
            tuningLabel: null,
            stringCount: null,
            readable: true,
          ),
        ],
      ),
      onExport: (_, format, _) async => exports.add(format),
    );
    await chooseFromMenu(tester, 'Export as PDF');
    expect(exports, isEmpty);
  });

  testWidgets('a failed export says so', (tester) async {
    await pumpPage(
      tester,
      edited,
      onExport: (_, _, _) async => throw Exception('no room'),
    );
    await chooseFromMenu(tester, 'Export as .gp');
    expect(find.textContaining("Couldn't export"), findsOneWidget);
  });

  testWidgets('a song row keeps its own export state', (tester) async {
    SongListEntry song(String name) => SongListEntry(
      path: '$name.gp',
      name: name,
      tuningLabel: null,
      stringCount: 6,
      readable: true,
    );
    final library = _Library();
    final states = StreamController<LibraryState>();
    addTearDown(states.close);
    whenListen(
      library,
      states.stream,
      initialState: LibraryState(loading: false, songs: [song('B'), song('C')]),
    );
    when(library.refresh).thenAnswer((_) async {});
    final exporting = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<LibraryCubit>.value(
            value: library,
            child: LibraryPage(
              onOpen: (_) {},
              onNewSong: (_) async {},
              onDelete: (_) async {},
              onRename: (_, _, {original}) async => null,
              onImport: () async {},
              onExport: (_, _, _) => exporting.future,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Song actions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export as .gp'));
    await tester.pump();
    states.add(
      LibraryState(loading: false, songs: [song('A'), song('B'), song('C')]),
    );
    await tester.pump();
    Finder row(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(ListTile));
    expect(
      find.descendant(
        of: row('C'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    exporting.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('an import that fails says so', (tester) async {
    await pumpPage(
      tester,
      const LibraryState(loading: false, songs: []),
      importFailures: Stream.value('Cloud Song.gp'),
    );
    await tester.pump();
    expect(find.text("Couldn't import Cloud Song.gp"), findsOneWidget);
  });
}
