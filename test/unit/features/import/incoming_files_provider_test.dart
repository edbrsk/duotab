import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duotab/features/import/incoming_files_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory documents;
  late StreamController<dynamic> events;
  late List<String> imported;
  late IncomingFilesProvider provider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('incoming_test');
    documents = Directory(p.join(root.path, 'documents'))..createSync();
    events = StreamController<dynamic>();
    imported = [];
    provider = IncomingFilesProvider(
      events: events.stream,
      documents: documents,
      onImported: (path) async => imported.add(path),
    );
  });

  tearDown(() async {
    provider.dispose();
    await events.close();
    await root.delete(recursive: true);
  });

  File file(String path, List<int> bytes) => File(p.join(root.path, path))
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  /// What the iOS runner sends: the original location, and a staged copy
  /// unless the original is already in Documents.
  void arrive({required File original, File? staged}) => events.add(
    jsonEncode({'original': original.path, 'staged': staged?.path}),
  );

  // The provider does real file I/O, so wait for the callbacks rather than a
  // fixed number of event-loop turns.
  Future<void> imports(int count) async {
    while (imported.length < count) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('moves an incoming file into Documents and reports it', () async {
    final staged = file('incoming/x/song.gp', [1, 2, 3]);
    arrive(original: file('mail/song.gp', [1, 2, 3]), staged: staged);
    await imports(1);

    expect(imported, ['song.gp']);
    expect(File(p.join(documents.path, 'song.gp')).readAsBytesSync(), [
      1,
      2,
      3,
    ]);
    expect(staged.parent.existsSync(), isFalse);
  });

  test('keeps both when a song with the same name exists', () async {
    File(p.join(documents.path, 'song.gp')).writeAsBytesSync([9]);
    arrive(
      original: file('mail/song.gp', [1]),
      staged: file('incoming/x/song.gp', [1]),
    );
    await imports(1);

    expect(imported, ['song (2).gp']);
    expect(File(p.join(documents.path, 'song.gp')).readAsBytesSync(), [9]);
  });

  test('two same-named files arriving together keep both', () async {
    arrive(
      original: file('a/song.gp', [1]),
      staged: file('incoming/1/song.gp', [1]),
    );
    arrive(
      original: file('b/song.gp', [2]),
      staged: file('incoming/2/song.gp', [2]),
    );
    await imports(2);

    expect(imported, ['song.gp', 'song (2).gp']);
    expect(File(p.join(documents.path, 'song.gp')).readAsBytesSync(), [1]);
    expect(File(p.join(documents.path, 'song (2).gp')).readAsBytesSync(), [2]);
  });

  test("never deletes an original outside the app's own Inbox", () async {
    final original = file('iCloud Drive/Inbox/song.gp', [1]);
    arrive(original: original, staged: file('incoming/x/song.gp', [1]));
    await imports(1);

    expect(original.existsSync(), isTrue);
  });

  test('removes the copy iOS leaves in Documents/Inbox', () async {
    final original = File(p.join(documents.path, 'Inbox', 'song.gp'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    arrive(original: original, staged: file('incoming/x/song.gp', [1]));
    await imports(1);

    expect(imported, ['song.gp']);
    expect(original.existsSync(), isFalse);
    expect(original.parent.existsSync(), isFalse);
  });

  test('opens a song already in Documents where it is', () async {
    final original = File(p.join(documents.path, 'song.gp'))
      ..writeAsBytesSync([1]);
    arrive(original: original);
    await imports(1);

    expect(imported, ['song.gp']);
    expect(documents.listSync(), hasLength(1));
  });
}
