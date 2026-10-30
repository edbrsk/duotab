import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/library/library_cubit.dart';
import 'package:duotab/features/library/library_page.dart';
import 'package:duotab/features/library/song_files.dart';
import 'package:duotab/features/library/song_list_entry.dart';
import 'package:duotab/l10n/app_localizations.dart';
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
    Future<NameProblem?> Function(String path, String name)? onRename,
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
        home: BlocProvider<LibraryCubit>.value(
          value: library,
          child: LibraryPage(
            onOpen: onOpen ?? (_) {},
            onNewSong: onNewSong ?? (_) async {},
            onDelete: onDelete ?? (_) async {},
            onRename: onRename ?? (_, _) async => null,
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
      find.text(
        'Add Guitar Pro or MusicXML files in the Files app, under On My iPhone › DuoTab',
      ),
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
      onRename: (path, name) async {
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
    await pumpPage(tester, riff, onRename: (_, _) async => NameProblem.taken);
    await chooseFromMenu(tester, 'Rename');
    await tester.enterText(find.byType(TextField), 'Other');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Another song already has this name'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
