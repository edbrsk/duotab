import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class JsonFile {
  final File file;
  Future<void> _writes = Future.value();

  JsonFile(this.file);

  /// A missing or unreadable file reads as empty. An unreadable one is moved
  /// aside first, so the next write can't destroy what it still holds.
  Future<Map<String, dynamic>> read() async {
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on PathNotFoundException {
      return {};
    } on Object catch (e) {
      debugPrint('JsonFile ${file.path}: $e');
      await _keepAside();
      return {};
    }
  }

  Future<void> _keepAside() async {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}${two(t.second)}';
    try {
      await file.rename('${file.path}.damaged-$stamp');
    } on Object catch (e) {
      debugPrint('JsonFile ${file.path}: could not keep it aside: $e');
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
