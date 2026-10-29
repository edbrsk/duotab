import 'dart:io';

import 'package:path/path.dart' as p;

/// A path in [dir] for [fileName] that does not exist yet, adding " (2)",
/// " (3)"… before the extension when needed.
File uniqueDestination(Directory dir, String fileName) {
  final base = p.basenameWithoutExtension(fileName);
  final extension = p.extension(fileName);
  var candidate = File(p.join(dir.path, fileName));
  for (var n = 2; candidate.existsSync(); n++) {
    candidate = File(p.join(dir.path, '$base ($n)$extension'));
  }
  return candidate;
}
