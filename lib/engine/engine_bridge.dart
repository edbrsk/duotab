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

  Future<void> setSpeed(double speed) => _request('setSpeed', {'speed': speed});

  Future<void> setLooping({required bool looping}) =>
      _request('setLooping', {'looping': looping});

  Future<void> setRange(PlaybackRange? range) =>
      _request('setRange', {'range': range?.toJson()});

  Future<void> setPlayerOptions({
    required bool countIn,
    required bool metronome,
  }) => _request('setPlayerOptions', {
    'countIn': countIn,
    'metronome': metronome,
  });

  Future<void> setStaves(List<StaffView> staves) => _request('setStaves', {
    'staves': [for (final s in staves) s.toJson()],
  });

  Future<EditState> edit(EditCommand command) async => EditState.fromJson(
    (await _request('edit', {'command': command.toJson()}))!
        as Map<String, dynamic>,
  );

  Future<EditState> undo() async => EditState.fromJson(
    (await _request('undo', const {}))! as Map<String, dynamic>,
  );

  Future<EditState> redo() async => EditState.fromJson(
    (await _request('redo', const {}))! as Map<String, dynamic>,
  );

  Future<SongSummary> newSong(NewSongOptions options) async =>
      SongSummary.fromJson(
        (await _request('newSong', options.toJson()))! as Map<String, dynamic>,
      );

  Future<Uint8List> exportGp() async => base64Decode(
    ((await _request('exportGp', const {}))! as Map<String, dynamic>)['base64']
        as String,
  );

  /// Rendering a long song's pages takes seconds, beyond [timeout].
  Future<PdfPages> exportPdf() async => PdfPages.fromJson(
    (await _request(
          'exportPdf',
          const {},
          timeout: const Duration(minutes: 1),
        ))!
        as Map<String, dynamic>,
  );

  /// A song file, not the open one, as `.gp`.
  Future<Uint8List> exportFileGp(String documentsRelativePath) async =>
      base64Decode(
        ((await _request('exportFileGp', {'path': documentsRelativePath}))!
                as Map<String, dynamic>)['base64']
            as String,
      );

  /// A song file's first guitar track as pages, with [staves] the owner chose
  /// for its tracks.
  Future<PdfPages> exportFilePdf(
    String documentsRelativePath,
    List<StaffView> staves,
  ) async => PdfPages.fromJson(
    (await _request('exportFilePdf', {
          'path': documentsRelativePath,
          'staves': [for (final s in staves) s.toJson()],
        }, timeout: const Duration(minutes: 1)))!
        as Map<String, dynamic>,
  );

  Future<void> setTracks(List<TrackMix> tracks) => _request('setTracks', {
    'tracks': [for (final t in tracks) t.toJson()],
  });

  /// −∞ is [double.negativeInfinity].
  Future<void> setMaster(double volumeDb) =>
      _request('setMaster', {'volumeDb': volumeDb.isFinite ? volumeDb : null});

  /// Waits for the engine page to load, so the timeout also covers an engine
  /// that never starts.
  Future<Object?> _request(
    String type,
    Map<String, Object?> payload, {
    Duration? timeout,
  }) async {
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
      }().timeout(
        timeout ?? this.timeout,
        onTimeout: () => throw EngineTimeout(type),
      );
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
