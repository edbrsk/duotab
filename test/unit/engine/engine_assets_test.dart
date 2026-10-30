import 'dart:io';

import 'package:duoscore/engine/engine_assets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bundle extends CachingAssetBundle {
  final Map<String, List<int>> assets;

  _Bundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final asset in assets.keys)
          asset: [
            {'asset': asset},
          ],
      })!;
    }
    return ByteData.sublistView(Uint8List.fromList(assets[key]!));
  }
}

void main() {
  late Directory destination;
  final long = DateTime(2020);

  setUp(() async {
    destination = await Directory.systemTemp.createTemp('engine_assets_test');
  });

  tearDown(() => destination.delete(recursive: true));

  File file(String path) => File('${destination.path}/$path');

  test('a launch leaves unchanged assets as they are', () async {
    final bundle = _Bundle({
      'assets/engine/soundfont/bank.sf2': [1, 2, 3],
    });
    await extractEngineAssets(destination, bundle: bundle);
    file('soundfont/bank.sf2').setLastModifiedSync(long);

    await extractEngineAssets(destination, bundle: bundle);

    expect(file('soundfont/bank.sf2').lastModifiedSync(), long);
  });

  test('a changed asset is written again', () async {
    await extractEngineAssets(
      destination,
      bundle: _Bundle({
        'assets/engine/engine.js': [1, 2, 3],
      }),
    );
    await extractEngineAssets(
      destination,
      bundle: _Bundle({
        'assets/engine/engine.js': [1, 2, 4],
      }),
    );
    expect(file('engine.js').readAsBytesSync(), [1, 2, 4]);
  });

  test('an asset no longer bundled is removed', () async {
    await extractEngineAssets(
      destination,
      bundle: _Bundle({
        'assets/engine/engine.js': [1],
        'assets/engine/alphatab/soundfont/old.sf2': [2],
      }),
    );
    await extractEngineAssets(
      destination,
      bundle: _Bundle({
        'assets/engine/engine.js': [1],
      }),
    );
    expect(file('alphatab/soundfont/old.sf2').existsSync(), isFalse);
    expect(file('engine.js').existsSync(), isTrue);
  });

  test('assets outside the engine are not copied', () async {
    await extractEngineAssets(
      destination,
      bundle: _Bundle({
        'assets/engine/engine.js': [1],
        'assets/icon.png': [2],
      }),
    );
    expect(
      destination.listSync(recursive: true).whereType<File>().map((f) => f.path),
      [file('engine.js').path],
    );
  });
}
