import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The iOS Files picker. Chosen songs arrive through the incoming files, as
/// files opened from other apps do.
class SongPicker {
  static const _channel = MethodChannel('dev.edbrsk.duoscore/song_picker');

  const SongPicker();

  /// How many songs were chosen; 0 when cancelled.
  Future<int> pick() async {
    try {
      return await _channel.invokeMethod<int>('pick') ?? 0;
    } on PlatformException catch (e) {
      debugPrint('SongPicker: $e');
      return 0;
    }
  }
}
