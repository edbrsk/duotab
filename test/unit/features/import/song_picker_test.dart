import 'package:duoscore/features/import/song_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.edbrsk.duoscore/song_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('asks iOS for the Files picker and tells how many songs came', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return 2;
    });
    expect(await const SongPicker().pick(), 2);
    expect(calls, ['pick']);
  });

  test('a picker that fails imports nothing', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'busy'),
    );
    expect(await const SongPicker().pick(), 0);
  });
}
