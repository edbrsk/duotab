import 'dart:io';

import 'package:duotab/features/import/unique_destination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('unique_destination_test');
    File(p.join(dir.path, '07 Collateral Damage.gp')).writeAsBytesSync([1]);
    File(p.join(dir.path, '07 Collateral Damage (2).gp')).writeAsBytesSync([2]);
  });

  tearDown(() => dir.delete(recursive: true));

  test('uniqueDestination adds a counter before the extension', () {
    expect(
      p.basename(uniqueDestination(dir, '07 Collateral Damage.gp').path),
      '07 Collateral Damage (3).gp',
    );
    expect(p.basename(uniqueDestination(dir, 'new.gp').path), 'new.gp');
  });
}
