import 'dart:async';
import 'dart:convert';

import 'package:duoscore/engine/engine_transport.dart';

class FakeTransport implements EngineTransport {
  final sent = <String>[];
  final _incoming = StreamController<String>.broadcast();

  @override
  Future<void> send(String json) async => sent.add(json);

  @override
  Stream<String> get incoming => _incoming.stream;

  Map<String, dynamic> get lastRequest =>
      jsonDecode(sent.last) as Map<String, dynamic>;

  void deliver(Map<String, dynamic> message) =>
      _incoming.add(jsonEncode(message));

  Future<void> close() => _incoming.close();
}
