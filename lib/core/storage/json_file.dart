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

  /// Atomic, and in call order.
  Future<void> write(Map<String, dynamic> data) {
    final text = jsonEncode(data);
    return _writes = _writes.then((_) async {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(text, flush: true);
      await temp.rename(file.path);
    });
  }
}
