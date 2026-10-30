import 'dart:io';

import 'package:duotab/core/storage/json_file.dart';
import 'package:duotab/features/editor/owned_files.dart';
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
}
