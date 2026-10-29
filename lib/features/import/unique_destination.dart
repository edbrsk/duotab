import 'dart:io';

import 'package:path/path.dart' as p;

/// Claims a new, empty file in [dir] for [fileName], adding " (2)", " (3)"…
/// before the extension when the name is taken. Creating the file
/// exclusively keeps two imports from choosing the same name.
File uniqueDestination(Directory dir, String fileName) {
  final base = p.basenameWithoutExtension(fileName);
  final extension = p.extension(fileName);
  for (var n = 1; ; n++) {
    final name = n == 1 ? fileName : '$base ($n)$extension';
    final candidate = File(p.join(dir.path, name));
    try {
      candidate.createSync(exclusive: true);
      return candidate;
    } on FileSystemException {
      if (!candidate.existsSync()) rethrow;
    }
  }
}
