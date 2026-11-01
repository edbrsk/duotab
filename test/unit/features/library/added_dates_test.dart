import 'dart:io';

import 'package:duoscore/core/storage/json_file.dart';
import 'package:duoscore/features/library/added_dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late DateTime now;
  late AddedDates dates;

  AddedDates open() => AddedDates(
    JsonFile(File(p.join(dir.path, 'added.json'))),
    now: () => now,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('added_dates_test');
    now = DateTime.utc(2026, 11, 1, 12);
    dates = open();
  });

  tearDown(() => dir.delete(recursive: true));

  DateTime fileDate(String path) => DateTime.utc(2026, 1, path.length);

  test('the first time, each song takes its file date', () async {
    final first = await dates.datesFor(['ab.gp', 'abcd.gp'], fileDate);
    expect(first, {
      'ab.gp': DateTime.utc(2026, 1, 5),
      'abcd.gp': DateTime.utc(2026, 1, 7),
    });
  });

  test('a song that arrives later is dated when it is first seen', () async {
    await dates.datesFor(['ab.gp'], fileDate);
    now = DateTime.utc(2026, 11, 2);

    final later = await open().datesFor(['ab.gp', 'new.gp'], fileDate);
    expect(later['ab.gp'], DateTime.utc(2026, 1, 5));
    expect(later['new.gp'], DateTime.utc(2026, 11, 2));
  });

  test('a renamed song keeps its date', () async {
    await dates.datesFor(['ab.gp'], fileDate);
    await dates.rename('ab.gp', 'Riff.gp');

    final after = await open().datesFor(['Riff.gp'], fileDate);
    expect(after, {'Riff.gp': DateTime.utc(2026, 1, 5)});
  });

  test('a rename seen half done still keeps the date', () async {
    await dates.datesFor(['ab.gp'], fileDate);
    // A refresh between the file moving and its date moving.
    await dates.datesFor(['Riff.gp'], fileDate);
    await dates.rename('ab.gp', 'Riff.gp');

    final after = await dates.datesFor(['Riff.gp'], fileDate);
    expect(after['Riff.gp'], DateTime.utc(2026, 1, 5));
  });

  test('a deleted song is forgotten', () async {
    await dates.datesFor(['ab.gp'], fileDate);
    await dates.forget('ab.gp');
    now = DateTime.utc(2026, 11, 3);

    final again = await dates.datesFor(['ab.gp'], fileDate);
    expect(again['ab.gp'], DateTime.utc(2026, 11, 3));
  });
}
