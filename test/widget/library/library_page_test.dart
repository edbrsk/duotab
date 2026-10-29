import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/features/library/library_cubit.dart';
import 'package:duotab/features/library/library_page.dart';
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
          child: LibraryPage(onOpen: onOpen ?? (_) {}),
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
            title: 'Collateral Damage',
            tuningLabel: 'E♭ A♭ D♭ G♭ B♭ E♭',
            stringCount: 6,
            readable: true,
          ),
          SongListEntry(
            path: 'broken.gp5',
            title: 'broken.gp5',
            tuningLabel: null,
            stringCount: null,
            readable: false,
          ),
        ],
      ),
      onOpen: (path) => opened = path,
    );

    expect(find.text('Collateral Damage'), findsOneWidget);
    expect(find.textContaining('E♭ A♭ D♭ G♭ B♭ E♭'), findsOneWidget);
    expect(find.textContaining('6 strings'), findsOneWidget);
    expect(find.text("Can't open this file"), findsOneWidget);

    await tester.tap(find.text('Collateral Damage'));
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
}
