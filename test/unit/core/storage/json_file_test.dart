import 'dart:io';

import 'package:duotab/core/storage/json_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('json_file_test');
    file = File(p.join(dir.path, 'data.json'));
  });

  tearDown(() => dir.delete(recursive: true));

  test('a missing file reads as empty', () async {
    expect(await JsonFile(file).read(), isEmpty);
  });

  test('a corrupt file reads as empty', () async {
    file.writeAsStringSync('{not json');
    expect(await JsonFile(file).read(), isEmpty);
  });

  test('writes and reads back', () async {
    await JsonFile(file).write({'a': 1});
    expect(await JsonFile(file).read(), {'a': 1});
  });

  test('concurrent writes land in call order', () async {
    final json = JsonFile(file);
    final first = json.write({'n': 1});
    await json.write({'n': 2});
    await first;
    expect(await json.read(), {'n': 2});
  });
}
