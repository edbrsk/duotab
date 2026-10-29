import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

const _assetPrefix = 'assets/engine/';

/// Copies the bundled engine assets to [destination] so the asset server can
/// serve them from disk; asset bundles are not files.
Future<Directory> extractEngineAssets(Directory destination) async {
  if (destination.existsSync()) await destination.delete(recursive: true);
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  for (final asset in manifest.listAssets()) {
    if (!asset.startsWith(_assetPrefix)) continue;
    final data = await rootBundle.load(asset);
    final file = File(
      p.join(destination.path, asset.substring(_assetPrefix.length)),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }
  return destination;
}
