import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'unique_destination.dart';

/// Brings files opened in DuoTab from other apps into Documents, never
/// overwriting an existing song. The iOS runner sends each file's original
/// path and, unless it is already in Documents, a staged copy.
class IncomingFilesProvider {
  static const _channel = EventChannel('me.withedgar.duotab/incoming_files');

  final Directory documents;
  final Future<void> Function(String documentsRelativePath) onImported;
  StreamSubscription<dynamic>? _subscription;
  Future<void> _queue = Future.value();

  IncomingFilesProvider({
    required this.documents,
    required this.onImported,
    Stream<dynamic>? events,
  }) {
    _subscription = (events ?? _platformEvents())?.listen(
      // One at a time, so files from a single share cannot race for a name.
      (event) => _queue = _queue.then((_) => _import(event as String)),
      onError: (Object error) => debugPrint('IncomingFilesProvider: $error'),
    );
  }

  static Stream<dynamic>? _platformEvents() {
    // Only the iOS runner implements this channel.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    return _channel.receiveBroadcastStream();
  }

  Future<void> _import(String event) async {
    final message = jsonDecode(event) as Map<String, dynamic>;
    final original = File(message['original'] as String);
    final staged = switch (message['staged']) {
      final String path => File(path),
      _ => null,
    };
    final inbox = p.join(documents.path, 'Inbox');
    try {
      if (staged == null) {
        if (p.isWithin(documents.path, original.path) &&
            !p.isWithin(inbox, original.path)) {
          await onImported(p.relative(original.path, from: documents.path));
        }
        return;
      }
      final destination = uniqueDestination(
        documents,
        p.basename(original.path),
      );
      await destination.writeAsBytes(await staged.readAsBytes(), flush: true);
      // iOS copies some shares into Documents/Inbox; that copy is ours to remove.
      if (p.isWithin(inbox, original.path)) {
        await original.delete();
        final inboxDir = Directory(inbox);
        if (inboxDir.listSync().isEmpty) await inboxDir.delete();
      }
      await onImported(p.relative(destination.path, from: documents.path));
    } on Object catch (e) {
      debugPrint(
        'IncomingFilesProvider: could not import ${original.path}: $e',
      );
    } finally {
      if (staged != null && staged.parent.existsSync()) {
        await staged.parent.delete(recursive: true);
      }
    }
  }

  void dispose() => _subscription?.cancel();
}
