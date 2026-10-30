import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/core/storage/json_file.dart';
import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/owned_files.dart';
import 'package:duoscore/features/library/library_cubit.dart';
import 'package:duoscore/features/library/song_list_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Engine extends Mock implements EngineBridge {}

SongSummary _song(String title, {List<int>? tuning}) => SongSummary(
  title: title,
  tracks: [
    TrackSummary(
      index: 0,
      name: 'Guitar 1',
      kind: TrackKind.guitar,
      stringCount: tuning?.length ?? 6,
      tuning: tuning ?? const [64, 59, 55, 50, 45, 40],
      midiProgram: 29,
    ),
  ],
);

void main() {
  late Directory documents;
  late _Engine engine;
  late OwnedFiles owned;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('library_test');
    File('${documents.path}/b.gp').writeAsBytesSync([1]);
    File('${documents.path}/a.gp5').writeAsBytesSync([2]);
    File('${documents.path}/notes.txt').writeAsStringSync('not a song');
    engine = _Engine();
    owned = OwnedFiles(JsonFile(File('${documents.path}/owned.json')));
    when(() => engine.summarize('b.gp')).thenAnswer((_) async => _song('B'));
    when(() => engine.summarize('a.gp5')).thenAnswer((_) async => _song('A'));
  });

  tearDown(() => documents.delete(recursive: true));

  blocTest<LibraryCubit, LibraryState>(
    'lists supported files by file name, sorted',
    build: () =>
        LibraryCubit(documents: documents, engine: engine, owned: owned),
    act: (cubit) => cubit.refresh(),
    expect: () => [
      isA<LibraryState>().having((s) => s.loading, 'loading', isTrue),
      isA<LibraryState>().having((s) => s.loading, 'loading', isFalse).having(
        (s) => s.songs.map((e) => e.name),
        'names',
        ['a', 'b'],
      ),
    ],
  );

  test('lists a broken file as unreadable', () async {
    when(
      () => engine.summarize('a.gp5'),
    ).thenThrow(const EngineException('No compatible importer found for file'));
    final cubit = LibraryCubit(
      documents: documents,
      engine: engine,
      owned: owned,
    );
    addTearDown(cubit.close);

    await cubit.refresh();

    final broken = cubit.state.songs.singleWhere((e) => e.path == 'a.gp5');
    expect(broken.readable, isFalse);
    expect(broken.name, 'a');
    expect(cubit.state.songs.where((e) => e.readable).single.name, 'b');
  });

  test('asks the engine only about files that changed', () async {
    final cubit = LibraryCubit(
      documents: documents,
      engine: engine,
      owned: owned,
    );
    addTearDown(cubit.close);
    await cubit.refresh();

    File('${documents.path}/b.gp')
      ..writeAsBytesSync([1, 2])
      ..setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
    await cubit.refresh();

    verify(() => engine.summarize('a.gp5')).called(1);
    verify(() => engine.summarize('b.gp')).called(2);
  });

  test('retries a file whose summary timed out', () async {
    when(() => engine.summarize('a.gp5'))
        .thenThrow(const EngineTimeout('summarize'));
    final cubit = LibraryCubit(
      documents: documents,
      engine: engine,
      owned: owned,
    );
    addTearDown(cubit.close);
    await cubit.refresh();

    when(() => engine.summarize('a.gp5')).thenAnswer((_) async => _song('A'));
    await cubit.refresh();

    expect(cubit.state.songs.map((e) => e.name), ['a', 'b']);
    verify(() => engine.summarize('a.gp5')).called(2);
  });

  test('asks the engine about every changed file at once', () async {
    final a = Completer<SongSummary>();
    final b = Completer<SongSummary>();
    when(() => engine.summarize('a.gp5')).thenAnswer((_) => a.future);
    when(() => engine.summarize('b.gp')).thenAnswer((_) => b.future);
    final cubit = LibraryCubit(
      documents: documents,
      engine: engine,
      owned: owned,
    );
    addTearDown(cubit.close);

    final refresh = cubit.refresh();
    await pumpEventQueue();
    verify(() => engine.summarize('a.gp5')).called(1);
    verify(() => engine.summarize('b.gp')).called(1);

    a.complete(_song('A'));
    b.complete(_song('B'));
    await refresh;
  });

  test('an unexpected error for one file does not stop the list', () async {
    when(() => engine.summarize('a.gp5')).thenThrow(StateError('bad reply'));
    final cubit = LibraryCubit(
      documents: documents,
      engine: engine,
      owned: owned,
    );
    addTearDown(cubit.close);

    await cubit.refresh();

    expect(cubit.state.loading, isFalse);
    expect(
      cubit.state.songs.singleWhere((e) => e.path == 'a.gp5').readable,
      isFalse,
    );
  });

  test('labels the tuning low to high with flats', () {
    expect(tuningLabel(const [63, 58, 54, 49, 44, 39]), 'E♭ A♭ D♭ G♭ B♭ E♭');
    expect(tuningLabel(const [64, 59, 55, 50, 45, 40, 35]), 'B E A D G B E');
  });

  test('refreshes asked for at once run once, then once more', () async {
    final cubit = LibraryCubit(
      documents: documents,
      engine: engine,
      owned: owned,
    );
    addTearDown(cubit.close);
    await Future.wait([cubit.refresh(), cubit.refresh(), cubit.refresh()]);
    verify(() => engine.summarize('b.gp')).called(1);
    expect(cubit.state.songs, hasLength(2));
  });

  test('a refresh forgets app-made files that are gone', () async {
    await owned.add('gone.gp');
    final cubit = LibraryCubit(
      documents: documents,
      engine: engine,
      owned: owned,
    );
    addTearDown(cubit.close);
    await cubit.refresh();
    expect(await owned.all(), isEmpty);
  });

  group('edited copies', () {
    setUp(() {
      when(() => engine.summarize(any()))
          .thenAnswer((_) async => _song('Song'));
    });

    Future<List<SongListEntry>> songs() async {
      final cubit = LibraryCubit(
        documents: documents,
        engine: engine,
        owned: owned,
      );
      addTearDown(cubit.close);
      await cubit.refresh();
      return cubit.state.songs;
    }

    test('a recorded copy stands for its original, under its name', () async {
      File('${documents.path}/b (DuoScore).gp').writeAsBytesSync([3]);
      await owned.addCopy('b (DuoScore).gp', of: 'b.gp');
      final entries = await songs();
      expect(entries.map((e) => e.path), ['a.gp5', 'b (DuoScore).gp']);
      expect(entries.last.name, 'b');
      expect(entries.last.original, 'b.gp');
      expect(entries.first.original, isNull);
    });

    test('a copy made before copies were recorded is paired by name', () async {
      File('${documents.path}/a (DuoScore).gp').writeAsBytesSync([3]);
      await owned.add('a (DuoScore).gp');
      final entries = await songs();
      expect(entries.map((e) => e.path), ['a (DuoScore).gp', 'b.gp']);
      expect(entries.first.original, 'a.gp5');
      expect(entries.first.name, 'a');
    });

    test(
      "a file named like a copy that the app didn't make stays apart",
      () async {
        File('${documents.path}/a (DuoScore).gp').writeAsBytesSync([3]);
        final entries = await songs();
        expect(entries.map((e) => e.name), ['a', 'a (DuoScore)', 'b']);
        expect(entries.every((e) => e.original == null), isTrue);
      },
    );

    test('copies are paired by name only once', () async {
      File('${documents.path}/c (DuoScore).gp').writeAsBytesSync([3]);
      await owned.add('c (DuoScore).gp');
      await songs();
      File('${documents.path}/c.gp').writeAsBytesSync([4]);
      final entries = await songs();
      expect(entries.map((e) => e.name), ['a', 'b', 'c', 'c (DuoScore)']);
      expect(entries.every((e) => e.original == null), isTrue);
    });

    test('a copy whose name fits two songs pairs with neither', () async {
      File('${documents.path}/b.gpx').writeAsBytesSync([5]);
      File('${documents.path}/b (DuoScore).gp').writeAsBytesSync([3]);
      await owned.add('b (DuoScore).gp');
      final entries = await songs();
      expect(entries.every((e) => e.original == null), isTrue);
      expect(entries, hasLength(4));
    });

    test('a second copy of one original keeps its own name', () async {
      File('${documents.path}/b (DuoScore).gp').writeAsBytesSync([3]);
      File('${documents.path}/b (DuoScore) (2).gp').writeAsBytesSync([4]);
      await owned.addCopy('b (DuoScore).gp', of: 'b.gp');
      await owned.addCopy('b (DuoScore) (2).gp', of: 'b.gp');
      final entries = await songs();
      expect(entries.map((e) => e.name), ['a', 'b', 'b (DuoScore) (2)']);
      expect(entries.where((e) => e.original == 'b.gp'), hasLength(2));
    });
  });
}
