import 'dart:io';

import 'package:duoscore/core/storage/json_file.dart';
import 'package:duoscore/features/editor/owned_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late OwnedFiles owned;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('owned_files_test');
    owned = OwnedFiles(JsonFile(File(p.join(dir.path, 'owned.json'))));
  });

  tearDown(() => dir.delete(recursive: true));

  test('forgets a deleted song', () async {
    await owned.add('a.gp');
    await owned.remove('a.gp');
    expect(await owned.owns('a.gp'), isFalse);
  });

  test('a renamed song stays owned under its new name', () async {
    await owned.add('a.gp');
    await owned.rename('a.gp', 'c.gp');
    expect(await owned.owns('a.gp'), isFalse);
    expect(await owned.owns('c.gp'), isTrue);
  });

  test('renaming a song it does not own owns nothing', () async {
    await owned.rename('a.gp', 'c.gp');
    expect(await owned.owns('c.gp'), isFalse);
  });

  test('a copy remembers its original through renames and removal', () async {
    await owned.addCopy('a (DuoScore).gp', of: 'a.gp');
    expect(await owned.owns('a (DuoScore).gp'), isTrue);
    expect(await owned.originals(), {'a (DuoScore).gp': 'a.gp'});

    await owned.rename('a.gp', 'b.gp');
    await owned.rename('a (DuoScore).gp', 'b (DuoScore).gp');
    expect(await owned.originals(), {'b (DuoScore).gp': 'b.gp'});

    await owned.remove('b.gp');
    expect(await owned.originals(), isEmpty);
  });

  test('remembers that copies were paired once', () async {
    expect(await owned.pairedByName(), isFalse);
    await owned.markPairedByName();
    expect(await owned.pairedByName(), isTrue);
    await owned.add('a.gp');
    expect(await owned.pairedByName(), isTrue);
  });

  test('owned changes run one at a time', () async {
    await owned.add('a.gp');
    await Future.wait([
      owned.addCopy('b (DuoScore).gp', of: 'b.gp'),
      owned.rename('a.gp', 'c.gp'),
      owned.add('d.gp'),
    ]);
    expect(await owned.all(), {'b (DuoScore).gp', 'c.gp', 'd.gp'});
    expect(await owned.originals(), {'b (DuoScore).gp': 'b.gp'});
  });

  test('a refresh forgets owned files that are gone', () async {
    await owned.addCopy('b (DuoScore).gp', of: 'b.gp');
    await owned.add('x.gp');
    await owned.forgetMissing((path) => path == 'x.gp');
    expect(await owned.all(), {'x.gp'});
    expect(await owned.originals(), isEmpty);
  });
}
