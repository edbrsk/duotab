import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'unique_destination.dart';

/// Moves files opened in DuoTab from other apps (staged by the iOS runner)
/// into Documents, never overwriting an existing song.
class IncomingFilesProvider {
  static const _channel = EventChannel('me.withedgar.duotab/incoming_files');

  final Directory documents;
  final Future<void> Function(String documentsRelativePath) onImported;
  StreamSubscription<dynamic>? _subscription;

  IncomingFilesProvider({
    required this.documents,
    required this.onImported,
    Stream<dynamic>? events,
  }) {
    _subscription = (events ?? _platformEvents())?.listen(
      (event) => _import(event as String),
      onError: (Object error) => debugPrint('IncomingFilesProvider: $error'),
    );
  }

  static Stream<dynamic>? _platformEvents() {
    // Only the iOS runner implements this channel.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    return _channel.receiveBroadcastStream();
  }

  Future<void> _import(String stagedPath) async {
    final staged = File(stagedPath);
    final destination = uniqueDestination(documents, p.basename(stagedPath));
    // Staging lives in Caches, which can be another volume, so copy then delete.
    await staged.copy(destination.path);
    await staged.parent.delete(recursive: true);
    await onImported(p.relative(destination.path, from: documents.path));
  }

  void dispose() => _subscription?.cancel();
}
