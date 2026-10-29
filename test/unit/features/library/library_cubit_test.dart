import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/library/library_cubit.dart';
import 'package:duotab/features/library/song_list_entry.dart';
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

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('library_test');
    File('${documents.path}/b.gp').writeAsBytesSync([1]);
    File('${documents.path}/a.gp5').writeAsBytesSync([2]);
    File('${documents.path}/notes.txt').writeAsStringSync('not a song');
    engine = _Engine();
    when(() => engine.summarize('b.gp')).thenAnswer((_) async => _song('B'));
    when(() => engine.summarize('a.gp5')).thenAnswer((_) async => _song('A'));
  });

  tearDown(() => documents.delete(recursive: true));

  blocTest<LibraryCubit, LibraryState>(
    'lists supported files sorted by title',
    build: () => LibraryCubit(documents: documents, engine: engine),
    act: (cubit) => cubit.refresh(),
    expect: () => [
      isA<LibraryState>().having((s) => s.loading, 'loading', isTrue),
      isA<LibraryState>().having((s) => s.loading, 'loading', isFalse).having(
        (s) => s.songs.map((e) => e.title),
        'titles',
        ['A', 'B'],
      ),
    ],
  );

  test('lists a broken file as unreadable', () async {
    when(
      () => engine.summarize('a.gp5'),
    ).thenThrow(const EngineException('No compatible importer found for file'));
    final cubit = LibraryCubit(documents: documents, engine: engine);
    addTearDown(cubit.close);

    await cubit.refresh();

    final broken = cubit.state.songs.singleWhere((e) => e.path == 'a.gp5');
    expect(broken.readable, isFalse);
    expect(broken.title, 'a.gp5');
    expect(cubit.state.songs.where((e) => e.readable).single.title, 'B');
  });

  test('asks the engine only about files that changed', () async {
    final cubit = LibraryCubit(documents: documents, engine: engine);
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
    final cubit = LibraryCubit(documents: documents, engine: engine);
    addTearDown(cubit.close);
    await cubit.refresh();

    when(() => engine.summarize('a.gp5')).thenAnswer((_) async => _song('A'));
    await cubit.refresh();

    expect(cubit.state.songs.map((e) => e.title), ['A', 'B']);
    verify(() => engine.summarize('a.gp5')).called(2);
  });

  test('asks the engine about every changed file at once', () async {
    final a = Completer<SongSummary>();
    final b = Completer<SongSummary>();
    when(() => engine.summarize('a.gp5')).thenAnswer((_) => a.future);
    when(() => engine.summarize('b.gp')).thenAnswer((_) => b.future);
    final cubit = LibraryCubit(documents: documents, engine: engine);
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
    final cubit = LibraryCubit(documents: documents, engine: engine);
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
}
