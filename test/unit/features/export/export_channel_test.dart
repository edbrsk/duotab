import 'package:duoscore/features/export/export_channel.dart';
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
}
