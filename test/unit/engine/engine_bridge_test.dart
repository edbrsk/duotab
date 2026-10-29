import 'package:duotab/engine/engine_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

void main() {
  late FakeTransport transport;
  late EngineBridge bridge;

  setUp(() {
    transport = FakeTransport();
    bridge = EngineBridge(transport);
  });

  Future<void> engineReady() async {
    transport.deliver({'event': 'ready', 'payload': <String, Object>{}});
    await pumpEventQueue();
  }

  tearDown(() async {
    bridge.dispose();
    await transport.close();
  });

  test('answers a request with the reply carrying the same id', () async {
    await engineReady();
    final summary = bridge.summarize('a.gp');
    await pumpEventQueue();
    final request = transport.lastRequest;
    expect(request['type'], 'summarize');
    expect(request['payload'], {'path': 'a.gp'});

    transport.deliver({
      'id': request['id'],
      'ok': true,
      'payload': {'title': 'A', 'tracks': <Object>[]},
    });

    expect((await summary).title, 'A');
  });

  test('throws EngineException on an error reply', () async {
    await engineReady();
    final summary = bridge.summarize('broken.gp5');
    await pumpEventQueue();
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': false,
      'error': 'No compatible importer found for file',
    });

    await expectLater(
      summary,
      throwsA(
        isA<EngineException>().having(
          (e) => e.message,
          'message',
          'No compatible importer found for file',
        ),
      ),
    );
  });

  test('times out a request the engine never answers', () async {
    final slow = EngineBridge(
      transport,
      timeout: const Duration(milliseconds: 50),
    );
    addTearDown(slow.dispose);

    await expectLater(slow.summarize('a.gp'), throwsA(isA<EngineTimeout>()));
  });

  test('holds requests until the engine is ready', () async {
    final summary = bridge.summarize('a.gp');
    await pumpEventQueue();
    expect(transport.sent, isEmpty);

    await engineReady();
    expect(transport.lastRequest['type'], 'summarize');
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': true,
      'payload': {'title': 'A', 'tracks': <Object>[]},
    });
    expect((await summary).title, 'A');
  });

  test('ready completes on the ready event', () async {
    var ready = false;
    bridge.ready.then((_) => ready = true).ignore();
    await pumpEventQueue();
    expect(ready, isFalse);

    transport.deliver({'event': 'ready', 'payload': <String, Object>{}});
    await pumpEventQueue();

    expect(ready, isTrue);
  });

  test('forwards engine events', () async {
    final events = <String>[];
    bridge.events.listen((e) => events.add(e.type));

    transport
      ..deliver({'event': 'rendered', 'payload': <String, Object>{}})
      ..deliver({
        'event': 'error',
        'payload': {'message': 'x'},
      });
    await pumpEventQueue();

    expect(events, ['rendered', 'error']);
  });
}
