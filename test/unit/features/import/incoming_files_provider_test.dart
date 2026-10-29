import 'dart:async';
import 'dart:io';

import 'package:duotab/features/import/incoming_files_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory documents;
  late StreamController<dynamic> events;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('incoming_test');
    documents = Directory(p.join(root.path, 'documents'))..createSync();
    events = StreamController<dynamic>();
  });

  tearDown(() async {
    await events.close();
    await root.delete(recursive: true);
  });

  File stage(String name, List<int> bytes) {
    final staging = Directory(p.join(root.path, 'incoming', 'x'))
      ..createSync(recursive: true);
    return File(p.join(staging.path, name))..writeAsBytesSync(bytes);
  }

  test('moves an incoming file into Documents and reports it', () async {
    final imported = <String>[];
    final provider = IncomingFilesProvider(
      events: events.stream,
      documents: documents,
      onImported: (path) async => imported.add(path),
    );
    addTearDown(provider.dispose);
    final staged = stage('song.gp', [1, 2, 3]);

    events.add(staged.path);
    await pumpEventQueue();

    expect(File(p.join(documents.path, 'song.gp')).readAsBytesSync(), [1, 2, 3]);
    expect(staged.parent.existsSync(), isFalse);
    expect(imported, ['song.gp']);
  });

  test('keeps both when a song with the same name exists', () async {
    File(p.join(documents.path, 'song.gp')).writeAsBytesSync([9]);
    final imported = <String>[];
    final provider = IncomingFilesProvider(
      events: events.stream,
      documents: documents,
      onImported: (path) async => imported.add(path),
    );
    addTearDown(provider.dispose);

    events.add(stage('song.gp', [1]).path);
    await pumpEventQueue();

    expect(File(p.join(documents.path, 'song.gp')).readAsBytesSync(), [9]);
    expect(imported, ['song (2).gp']);
  });
}
