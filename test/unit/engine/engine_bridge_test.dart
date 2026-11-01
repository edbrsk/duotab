import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:fake_async/fake_async.dart';
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

  test('play, pause and stop send their requests', () async {
    await engineReady();
    for (final (call, type) in [
      (bridge.play, 'play'),
      (bridge.pause, 'pause'),
      (bridge.stop, 'stop'),
    ]) {
      final done = call();
      await pumpEventQueue();
      expect(transport.lastRequest['type'], type);
      transport.deliver({
        'id': transport.lastRequest['id'],
        'ok': true,
        'payload': <String, Object>{},
      });
      await done;
    }
  });

  test('setMeters and setOutputLatency send their values', () async {
    await engineReady();
    for (final (call, type, payload) in [
      (() => bridge.setMeters(on: true), 'setMeters', {'on': true}),
      (
        () => bridge.setOutputLatency(const Duration(microseconds: 182500)),
        'setOutputLatency',
        {'ms': 182.5},
      ),
    ]) {
      final done = call();
      await pumpEventQueue();
      expect(transport.lastRequest['type'], type);
      expect(transport.lastRequest['payload'], payload);
      transport.deliver({
        'id': transport.lastRequest['id'],
        'ok': true,
        'payload': <String, Object>{},
      });
      await done;
    }
  });

  test('setStaves sends the views', () async {
    await engineReady();
    final done = bridge.setStaves(const [
      StaffView(index: 1, notation: false, tab: true),
    ]);
    await pumpEventQueue();
    expect(transport.lastRequest['type'], 'setStaves');
    expect(transport.lastRequest['payload'], {
      'staves': [
        {
          'index': 1,
          'notation': false,
          'tab': true,
          'slash': false,
          'numbered': false,
        },
      ],
    });
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': true,
      'payload': <String, Object>{},
    });
    await done;
  });

  test('edit sends the command and parses the edit state', () async {
    await engineReady();
    final state = bridge.edit(const SetFret(5));
    await pumpEventQueue();
    expect(transport.lastRequest['type'], 'edit');
    expect(transport.lastRequest['payload'], {
      'command': {'op': 'setFret', 'fret': 5},
    });
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': true,
      'payload': {
        'position': {'track': 0, 'bar': 2, 'voice': 0, 'beat': 1, 'string': 3},
        'issues': [
          {'bar': 2, 'voice': 0, 'ticksOff': -480},
        ],
        'canUndo': true,
        'canRedo': false,
        'edited': true,
        'song': {'title': 'T', 'tracks': <Object>[]},
        'beat': {
          'duration': 8,
          'dots': 0,
          'techniques': ['palmMute'],
          'dynamic': 'pp',
          'tuplet': 3,
          'hasNote': true,
          'bend': {'kind': 'bendRelease', 'amount': 6},
        },
        'bar': {
          'numerator': 6,
          'denominator': 8,
          'key': -3,
          'minor': true,
          'clef': 'bass',
          'tempo': 140,
          'tempoChange': true,
        },
        'canPaste': true,
        'drawnTrack': 2,
        'structure': {
          'repeatStart': true,
          'repeatCount': 3,
          'endings': [1, 2],
          'directions': ['segno', 'fine'],
        },
      },
    });
    final s = await state;
    expect(s.beatDuration, 8);
    expect(s.techniques, {'palmMute'});
    expect(s.dynamicMark, 'pp');
    expect(s.tuplet, 3);
    expect(s.hasNote, isTrue);
    expect(s.bendKind, 'bendRelease');
    expect(s.bendAmount, 6);
    expect(
      [s.barNumerator, s.barDenominator, s.barKey, s.barMinor, s.barClef],
      [6, 8, -3, true, 'bass'],
    );
    expect([s.barTempo, s.barTempoChange, s.canPaste], [140, true, true]);
    expect(
      [s.repeatStart, s.repeatCount, s.endings],
      [
        true,
        3,
        [1, 2],
      ],
    );
    expect(s.directions, {'segno', 'fine'});
    expect(s.drawnTrack, 2);
    expect(s.position!.bar, 2);
    expect(s.position!.string, 3);
    expect(s.issues.single.ticksOff, -480);
    expect(s.canUndo, isTrue);
    expect(s.edited, isTrue);
    expect(s.song.title, 'T');
  });

  test('exportGp decodes base64', () async {
    await engineReady();
    final bytes = bridge.exportGp();
    await pumpEventQueue();
    expect(transport.lastRequest['type'], 'exportGp');
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': true,
      'payload': {'base64': 'AQID'},
    });
    expect(await bytes, [1, 2, 3]);
  });

  test('exportPdf reads the pages and base URL', () async {
    await engineReady();
    final pages = bridge.exportPdf();
    await pumpEventQueue();
    expect(transport.lastRequest['type'], 'exportPdf');
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': true,
      'payload': {
        'pages': ['<p>1</p>', '<p>2</p>'],
        'baseUrl': 'http://127.0.0.1:1/',
      },
    });
    final reply = await pages;
    expect(reply.pages, ['<p>1</p>', '<p>2</p>']);
    expect(reply.baseUrl, 'http://127.0.0.1:1/');
  });

  test('exportFileGp and exportFilePdf send the file and staves', () async {
    await engineReady();
    final bytes = bridge.exportFileGp('a.gp5');
    await pumpEventQueue();
    expect(transport.lastRequest['type'], 'exportFileGp');
    expect(transport.lastRequest['payload'], {'path': 'a.gp5'});
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': true,
      'payload': {'base64': 'AQID'},
    });
    expect(await bytes, [1, 2, 3]);

    final pages = bridge.exportFilePdf('a.gp', const [
      StaffView(index: 1, notation: true, tab: false),
    ]);
    await pumpEventQueue();
    expect(transport.lastRequest['type'], 'exportFilePdf');
    expect(transport.lastRequest['payload'], {
      'path': 'a.gp',
      'staves': [
        {
          'index': 1,
          'notation': true,
          'tab': false,
          'slash': false,
          'numbered': false,
        },
      ],
    });
    transport.deliver({
      'id': transport.lastRequest['id'],
      'ok': true,
      'payload': {
        'pages': ['<p>1</p>'],
        'baseUrl': 'http://h/',
      },
    });
    expect((await pages).pages, ['<p>1</p>']);
  });

  test('exportPdf waits up to a minute', () {
    fakeAsync((async) {
      // Built inside the fake zone, so its streams run on fake time.
      final transport = FakeTransport();
      final bridge = EngineBridge(transport);
      transport.deliver({'event': 'ready', 'payload': <String, Object>{}});
      async.flushMicrotasks();
      PdfPages? answered;
      bridge.exportPdf().then((r) => answered = r);
      async.elapse(const Duration(seconds: 40));
      transport.deliver({
        'id': transport.lastRequest['id'],
        'ok': true,
        'payload': {'pages': <String>[], 'baseUrl': ''},
      });
      async.flushMicrotasks();
      expect(answered, isNotNull);

      Object? failure;
      bridge.exportPdf().catchError((Object e) {
        failure = e;
        return const PdfPages(pages: [], baseUrl: '');
      });
      async.elapse(const Duration(seconds: 59));
      expect(failure, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(
        failure,
        isA<EngineTimeout>().having((e) => e.requestType, 'type', 'exportPdf'),
      );
      bridge.dispose();
    });
  });

  test('every edit command serialises its op', () {
    const position = EditPosition(
      track: 0,
      bar: 1,
      voice: 0,
      beat: 2,
      string: 4,
    );
    expect(const DeleteNote().toJson(), {'op': 'deleteNote'});
    expect(const SetDuration(8, 1).toJson(), {
      'op': 'setDuration',
      'duration': 8,
      'dots': 1,
    });
    expect(const SetRest().toJson(), {'op': 'setRest'});
    expect(const SelectVoice(2).toJson(), {'op': 'selectVoice', 'voice': 2});
    expect(const Move('right').toJson(), {'op': 'move', 'direction': 'right'});
    expect(const Place(position).toJson(), {
      'op': 'place',
      'position': {'track': 0, 'bar': 1, 'voice': 0, 'beat': 2, 'string': 4},
    });
  });

  test('technique commands serialise their op', () {
    expect(const Toggle('slide').toJson(), {
      'op': 'toggle',
      'technique': 'slide',
    });
    expect(const SetDynamic('mf').toJson(), {
      'op': 'setDynamic',
      'dynamic': 'mf',
    });
    expect(const SetTuplet(5).toJson(), {'op': 'setTuplet', 'tuplet': 5});
    expect(const AddGrace().toJson(), {'op': 'addGrace'});
    expect(const SetBend('prebend', 8).toJson(), {
      'op': 'setBend',
      'bend': {'kind': 'prebend', 'amount': 8},
    });
    expect(const SetBend(null, 4).toJson(), {'op': 'setBend', 'bend': null});
    expect(const SetTitle('Riff').toJson(), {
      'op': 'setTitle',
      'title': 'Riff',
    });
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

  test(
    'a restart fails pending requests and waits for the next ready',
    () async {
      await engineReady();
      final pending = bridge.summarize('a.gp');
      await pumpEventQueue();

      bridge.restart();
      await expectLater(pending, throwsA(isA<EngineException>()));

      final later = bridge.summarize('b.gp');
      await pumpEventQueue();
      expect(transport.sent, hasLength(1));

      await engineReady();
      expect(transport.lastRequest['payload'], {'path': 'b.gp'});
      transport.deliver({
        'id': transport.lastRequest['id'],
        'ok': true,
        'payload': {'title': 'B', 'tracks': <Object>[]},
      });
      expect((await later).title, 'B');
    },
  );
}
