import 'dart:async';

import 'package:duoscore/features/export/export_channel.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.edbrsk.duoscore/export');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('makePdf sends pages, base URL and path', () async {
    await const ExportChannel().makePdf(
      pages: ['<p>1</p>', '<p>2</p>'],
      baseUrl: 'http://127.0.0.1:8080/',
      path: '/tmp/exports/Riff.pdf',
    );
    expect(calls.single.method, 'pdf');
    expect(calls.single.arguments, {
      'pages': ['<p>1</p>', '<p>2</p>'],
      'baseUrl': 'http://127.0.0.1:8080/',
      'path': '/tmp/exports/Riff.pdf',
    });
  });

  test('share sends the paths and the anchor rect', () async {
    await const ExportChannel().share([
      '/tmp/exports/Riff.gp',
    ], const Rect.fromLTWH(10, 20, 30, 40));
    expect(calls.single.method, 'share');
    expect(calls.single.arguments, {
      'paths': ['/tmp/exports/Riff.gp'],
      'x': 10.0,
      'y': 20.0,
      'width': 30.0,
      'height': 40.0,
    });
  });

  test('a platform error reaches the caller', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'pdf_failed'),
    );
    await expectLater(
      const ExportChannel().makePdf(pages: [''], baseUrl: '', path: ''),
      throwsA(isA<PlatformException>()),
    );
  });

  test('a PDF that iOS never finishes fails after two minutes', () {
    fakeAsync((async) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) => Completer<Object?>().future,
      );
      Object? failure;
      const ExportChannel()
          .makePdf(pages: [''], baseUrl: '', path: '')
          .catchError((Object e) => failure = e);
      async.elapse(const Duration(seconds: 119));
      expect(failure, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(failure, isA<TimeoutException>());
    });
  });
}
