import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

const _assetPrefix = 'assets/engine/';

/// Copies the bundled engine assets to [destination] so the asset server can
/// serve them from disk; asset bundles are not files.
///
/// Runs before the first frame, so a file already holding the bundled bytes
/// is left alone: rewriting the 32 MB SoundFont on every launch is slow on a
/// phone.
Future<Directory> extractEngineAssets(
  Directory destination, {
  AssetBundle? bundle,
}) async {
  bundle ??= rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final bundled = <String>{};
  for (final asset in manifest.listAssets()) {
    if (!asset.startsWith(_assetPrefix)) continue;
    final file = File(
      p.join(destination.path, asset.substring(_assetPrefix.length)),
    );
    bundled.add(file.path);
    final bytes = (await bundle.load(asset)).buffer.asUint8List();
    if (await _holds(file, bytes)) continue;
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
  if (destination.existsSync()) {
    await for (final entry in destination.list(recursive: true)) {
      if (entry is File && !bundled.contains(entry.path)) await entry.delete();
    }
  }
  return destination;
}

Future<bool> _holds(File file, Uint8List bytes) async {
  if (!file.existsSync() || file.lengthSync() != bytes.length) return false;
  final held = await file.readAsBytes();
  for (var i = 0; i < bytes.length; i++) {
    if (held[i] != bytes[i]) return false;
  }
  return true;
}
