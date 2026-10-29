import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class JsonFile {
  final File file;
  Future<void> _writes = Future.value();

  JsonFile(this.file);

  /// A missing or unreadable file reads as empty, so a damaged store only
  /// loses what it held.
  Future<Map<String, dynamic>> read() async {
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on Object catch (e) {
      if (e is! PathNotFoundException) debugPrint('JsonFile ${file.path}: $e');
      return {};
    }
  }

  /// Atomic, and in call order. A failed write fails only its own caller.
  Future<void> write(Map<String, dynamic> data) {
    final text = jsonEncode(data);
    final write = _writes.then((_) async {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(text, flush: true);
      await temp.rename(file.path);
    });
    _writes = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }
}
