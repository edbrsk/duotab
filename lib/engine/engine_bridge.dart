import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'engine_transport.dart';
import 'protocol.dart';

class EngineException implements Exception {
  final String message;

  const EngineException(this.message);

  @override
  String toString() => 'EngineException: $message';
}

class EngineTimeout implements Exception {
  final String requestType;

  const EngineTimeout(this.requestType);

  @override
  String toString() => 'EngineTimeout: $requestType';
}

/// Requests to the alphaTab engine in the web view, matched to replies by id.
class EngineBridge {
  final EngineTransport _transport;
  final Duration timeout;
  final _pending = <int, Completer<Object?>>{};
  var _ready = Completer<void>();
  final _events = StreamController<EngineEvent>.broadcast();
  late final StreamSubscription<String> _subscription;
  var _nextId = 0;

  EngineBridge(this._transport, {this.timeout = const Duration(seconds: 15)}) {
    _subscription = _transport.incoming.listen(_onMessage);
  }

  Future<void> get ready => _ready.future;

  /// After the web page died and is reloading: fails what was in flight and
  /// holds new requests until the reloaded page reports ready.
  void restart() {
    for (final reply in _pending.values) {
      if (!reply.isCompleted) {
        reply.completeError(const EngineException('The engine restarted'));
      }
    }
    if (_ready.isCompleted) _ready = Completer<void>();
  }

  Stream<EngineEvent> get events => _events.stream;

  Future<SongSummary> summarize(String documentsRelativePath) async =>
      SongSummary.fromJson(
        (await _request('summarize', {'path': documentsRelativePath}))!
            as Map<String, dynamic>,
      );

  Future<SongSummary> open(String documentsRelativePath) async =>
      SongSummary.fromJson(
        (await _request('open', {'path': documentsRelativePath}))!
            as Map<String, dynamic>,
      );

  Future<void> renderTrack(int index) =>
      _request('renderTrack', {'index': index});

  Future<void> play() => _request('play', const {});

  Future<void> pause() => _request('pause', const {});

  Future<void> stop() => _request('stop', const {});

  Future<void> seekBar(int bar) => _request('seekBar', {'bar': bar});

  /// Waits for the engine page to load, so the timeout also covers an engine
  /// that never starts.
  Future<Object?> _request(String type, Map<String, Object?> payload) async {
    final id = _nextId++;
    final reply = Completer<Object?>();
    _pending[id] = reply;
    try {
      return await () async {
        // A restart fails the reply, which also ends the wait for ready.
        await Future.any<Object?>([ready, reply.future]);
        await _transport.send(
          jsonEncode({'id': id, 'type': type, 'payload': payload}),
        );
        return reply.future;
      }().timeout(timeout, onTimeout: () => throw EngineTimeout(type));
    } finally {
      _pending.remove(id);
    }
  }

  void _onMessage(String raw) {
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException catch (e) {
      debugPrint('EngineBridge: unreadable message: $e');
      return;
    }
    if (message['event'] case final String type) {
      if (type == 'ready' && !_ready.isCompleted) _ready.complete();
      _events.add(
        EngineEvent(type, (message['payload'] as Map<String, dynamic>?) ?? {}),
      );
      return;
    }
    final reply = _pending[message['id']];
    if (reply == null || reply.isCompleted) return;
    if (message['ok'] == true) {
      reply.complete(message['payload']);
    } else {
      reply.completeError(EngineException('${message['error']}'));
    }
  }

  void dispose() {
    _subscription.cancel();
    _events.close();
  }
}
