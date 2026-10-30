import 'dart:async';
import 'dart:io';

import 'package:duoscore/core/storage/json_file.dart';
import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/owned_files.dart';
import 'package:duoscore/features/editor/song_saver.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../score/score_test_data.dart';

class _Engine extends Mock implements EngineBridge {}

void main() {
  late Directory root;
  late Directory documents;
  late _Engine engine;
  late ScoreCubit score;
  late OwnedFiles owned;
  late int saved;
  late SongSaver saver;
  var export = Uint8List.fromList([1, 2, 3]);

  setUpAll(
    () => registerFallbackValue(
      const NewSongOptions(
        title: '',
        tuning: [],
        tempo: 0,
        numerator: 0,
        denominator: 0,
      ),
    ),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('song_saver_test');
    documents = Directory(p.join(root.path, 'Documents'))..createSync();
    engine = _Engine();
    when(() => engine.events).thenAnswer((_) => const Stream.empty());
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
    when(() => engine.open(any())).thenAnswer((_) async => drumsAndTwoGuitars);
    when(() => engine.newSong(any())).thenAnswer(
      (_) async => SongSummary(
        title: 'Riff',
        tracks: [track(0, 'Guitar', TrackKind.guitar)],
      ),
    );
    export = Uint8List.fromList([1, 2, 3]);
    when(() => engine.exportGp()).thenAnswer((_) async => export);
    score = ScoreCubit(engine: engine);
    owned = OwnedFiles(JsonFile(File(p.join(root.path, 'owned.json'))));
    saved = 0;
    saver = SongSaver(
      documents: documents,
      engine: engine,
      score: score,
      owned: owned,
      onSaved: () async => saved++,
      delay: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    await score.close();
    await root.delete(recursive: true);
  });

  File doc(String name) => File(p.join(documents.path, name));

  Future<void> openFile(String name) async {
    doc(name).writeAsBytesSync([9]);
    await score.open(name);
  }

  test('the first edit of an opened file writes a copy beside it', () async {
    await openFile('a.gp');
    await saver.saveNow();
    expect(doc('a (DuoScore).gp').readAsBytesSync(), [1, 2, 3]);
    expect(doc('a.gp').readAsBytesSync(), [9]);
    expect(score.state.path, 'a (DuoScore).gp');
    expect(saved, 1);
  });

  test('the copy records the file it was made from', () async {
    await openFile('a.gp');
    await saver.saveNow();
    expect(await owned.originals(), {'a (DuoScore).gp': 'a.gp'});
  });

  test('later saves write the copy', () async {
    await openFile('a.gp');
    await saver.saveNow();
    export = Uint8List.fromList([4]);
    await saver.saveNow();
    expect(doc('a (DuoScore).gp').readAsBytesSync(), [4]);
    expect(doc('a (DuoScore) (2).gp').existsSync(), isFalse);
  });

  test('an existing copy name gets a counter', () async {
    doc('a (DuoScore).gp').writeAsBytesSync([7]);
    await openFile('a.gp');
    await saver.saveNow();
    expect(doc('a (DuoScore) (2).gp').readAsBytesSync(), [1, 2, 3]);
    expect(doc('a (DuoScore).gp').readAsBytesSync(), [7]);
  });

  test('a file the app did not create is never written', () async {
    await openFile('b (DuoScore).gp');
    await saver.saveNow();
    expect(doc('b (DuoScore).gp').readAsBytesSync(), [9]);
    expect(doc('b (DuoScore) (DuoScore).gp').readAsBytesSync(), [1, 2, 3]);
  });

  test('a copy in a subfolder stays in that folder', () async {
    Directory(p.join(documents.path, 'Sets')).createSync();
    await openFile(p.join('Sets', 'c.gp'));
    await saver.saveNow();
    expect(score.state.path, p.join('Sets', 'c (DuoScore).gp'));
  });

  test('schedule saves once after the delay', () async {
    await openFile('a.gp');
    for (var i = 0; i < 3; i++) {
      saver.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    verify(() => engine.exportGp()).called(1);
  });

  test('createSong saves a new song under its title', () async {
    const options = NewSongOptions(
      title: 'Riff',
      tuning: [64, 59, 55, 50, 45, 40],
      tempo: 120,
      numerator: 4,
      denominator: 4,
    );
    final path = await saver.createSong(options);
    expect(path, 'Riff.gp');
    expect(doc('Riff.gp').readAsBytesSync(), [1, 2, 3]);
    expect(await owned.owns('Riff.gp'), isTrue);
    expect(score.state.path, 'Riff.gp');
    export = Uint8List.fromList([5]);
    await saver.saveNow();
    expect(doc('Riff.gp').readAsBytesSync(), [5]);
  });

  test('a title with a slash still makes one file', () async {
    const options = NewSongOptions(
      title: 'AC/DC riff',
      tuning: [64, 59, 55, 50, 45, 40],
      tempo: 120,
      numerator: 4,
      denominator: 4,
    );
    expect(await saver.createSong(options), 'AC-DC riff.gp');
  });

  test('a song the engine refuses leaves no file behind', () async {
    when(() => engine.newSong(any())).thenThrow(const EngineException('no'));
    const options = NewSongOptions(
      title: 'Riff',
      tuning: [64, 59, 55, 50, 45, 40],
      tempo: 120,
      numerator: 4,
      denominator: 4,
    );
    await expectLater(
      saver.createSong(options),
      throwsA(isA<SongNotCreated>()),
    );
    expect(doc('Riff.gp').existsSync(), isFalse);
  });

  test('flush saves a pending edit at once', () async {
    await openFile('a.gp');
    saver.schedule();
    await saver.flush();
    expect(doc('a (DuoScore).gp').existsSync(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    verify(() => engine.exportGp()).called(1);
  });

  test('flush does nothing without edits', () async {
    await openFile('a.gp');
    await saver.flush();
    verifyNever(() => engine.exportGp());
    expect(doc('a (DuoScore).gp').existsSync(), isFalse);
  });

  test('opening another song cancels a pending save', () async {
    await openFile('a.gp');
    saver.schedule();
    await openFile('b.gp');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    verifyNever(() => engine.exportGp());
  });

  test(
    'a save is dropped when another song opened during the export',
    () async {
      await openFile('a.gp');
      final export = Completer<Uint8List>();
      when(() => engine.exportGp()).thenAnswer((_) => export.future);
      saver.schedule();
      final saving = saver.flush();
      await pumpEventQueue();
      await openFile('b.gp');
      export.complete(Uint8List.fromList([8]));
      await saving;
      expect(doc('a (DuoScore).gp').existsSync(), isFalse);
      expect(doc('b (DuoScore).gp').existsSync(), isFalse);
    },
  );

  test('a failed save stays pending and is retried', () async {
    await openFile('a.gp');
    when(() => engine.exportGp()).thenThrow(const EngineException('busy'));
    saver.schedule();
    await saver.flush();
    expect(doc('a (DuoScore).gp').existsSync(), isFalse);
    when(() => engine.exportGp()).thenAnswer((_) async => export);
    await saver.flush();
    expect(doc('a (DuoScore).gp').readAsBytesSync(), [1, 2, 3]);
  });

  test('an owned song is replaced without leaving a temporary file', () async {
    await openFile('a.gp');
    await saver.saveNow();
    export = Uint8List.fromList([6]);
    await saver.saveNow();
    expect(doc('a (DuoScore).gp').readAsBytesSync(), [6]);
    expect(
      documents.listSync().map((e) => p.basename(e.path)),
      isNot(contains(endsWith('.tmp'))),
    );
  });

  test('creating a song first saves the open one', () async {
    await openFile('a.gp');
    saver.schedule();
    const options = NewSongOptions(
      title: 'Riff',
      tuning: [64, 59, 55, 50, 45, 40],
      tempo: 120,
      numerator: 4,
      denominator: 4,
    );
    await saver.createSong(options);
    expect(doc('a (DuoScore).gp').readAsBytesSync(), [1, 2, 3]);
  });
}
