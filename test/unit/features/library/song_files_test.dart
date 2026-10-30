import 'dart:io';

import 'package:duoscore/core/storage/json_file.dart';
import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/features/editor/owned_files.dart';
import 'package:duoscore/features/editor/song_saver.dart';
import 'package:duoscore/features/library/song_files.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/practice_store.dart';
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
  late PracticeStore practice;
  late SongSaver saver;
  late SongFiles files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('song_files_test');
    documents = Directory(p.join(root.path, 'Documents'))..createSync();
    engine = _Engine();
    when(() => engine.events).thenAnswer((_) => const Stream.empty());
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
    when(() => engine.open(any())).thenAnswer((_) async => drumsAndTwoGuitars);
    when(() => engine.stop()).thenAnswer((_) async {});
    when(() => engine.exportGp())
        .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    score = ScoreCubit(engine: engine);
    owned = OwnedFiles(JsonFile(File(p.join(root.path, 'owned.json'))));
    practice = PracticeStore(
      JsonFile(File(p.join(root.path, 'practice.json'))),
    );
    saver = SongSaver(
      documents: documents,
      engine: engine,
      score: score,
      owned: owned,
      onSaved: () async {},
      delay: const Duration(milliseconds: 20),
    );
    files = SongFiles(
      documents: documents,
      score: score,
      saver: saver,
      practice: practice,
      owned: owned,
    );
  });

  tearDown(() async {
    saver.dispose();
    await score.close();
    await root.delete(recursive: true);
  });

  File doc(String name) => File(p.join(documents.path, name));

  Future<void> song(String name, {bool isOwned = false}) async {
    doc(name).writeAsBytesSync([9]);
    await practice.save(name, const PracticeSettings(speed: 0.5));
    if (isOwned) await owned.add(name);
  }

  test(
    'delete removes the file, its practice settings and ownership',
    () async {
      await song('a.gp', isOwned: true);
      await song('b.gp');
      await files.delete('a.gp');
      expect(doc('a.gp').existsSync(), isFalse);
      expect(await practice.load('a.gp'), isNull);
      expect(await owned.owns('a.gp'), isFalse);
      expect(doc('b.gp').existsSync(), isTrue);
    },
  );

  test(
    'deleting the open song closes it, and its pending save never lands',
    () async {
      await song('a.gp', isOwned: true);
      await score.open('a.gp');
      final openId = score.state.openId;
      saver.schedule();
      await files.delete('a.gp');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(documents.listSync(), isEmpty);
      expect(score.state.song, isNull);
      expect(score.state.path, isNull);
      expect(score.state.openId, isNot(openId));
      verify(() => engine.stop()).called(1);
    },
  );

  test('rename keeps the extension and moves practice and ownership', () async {
    await song('a.gp5', isOwned: true);
    expect(await files.rename('a.gp5', '  Riff 2 '), isNull);
    expect(doc('a.gp5').existsSync(), isFalse);
    expect(doc('Riff 2.gp5').readAsBytesSync(), [9]);
    expect((await practice.load('Riff 2.gp5'))!.speed, 0.5);
    expect(await owned.owns('Riff 2.gp5'), isTrue);
  });

  test('renaming the open song saves to the new name', () async {
    await song('a.gp', isOwned: true);
    await score.open('a.gp');
    saver.schedule();
    await files.rename('a.gp', 'b');
    expect(score.state.path, 'b.gp');
    await saver.saveNow();
    expect(doc('a.gp').existsSync(), isFalse);
    expect(doc('b.gp').readAsBytesSync(), [1, 2, 3]);
  });

  test('rename refuses an empty, invalid or taken name', () async {
    await song('a.gp');
    await song('b.gp');
    expect(await files.rename('a.gp', '  '), NameProblem.empty);
    expect(await files.rename('a.gp', 'x/y'), NameProblem.invalid);
    expect(await files.rename('a.gp', 'x:y'), NameProblem.invalid);
    expect(await files.rename('a.gp', 'b'), NameProblem.taken);
    expect(doc('a.gp').existsSync(), isTrue);
  });

  test('rename can change only the case', () async {
    await song('riff.gp');
    expect(await files.rename('riff.gp', 'Riff'), isNull);
    expect(documents.listSync().map((f) => p.basename(f.path)), ['Riff.gp']);
  });
}
