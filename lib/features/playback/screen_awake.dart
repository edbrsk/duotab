import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'playback_cubit.dart';

/// So a playing song can be read on a music stand. The screen starts out free
/// to dim.
StreamSubscription<bool> keepAwakeWhilePlaying(
  Stream<PlaybackState> states,
  Future<void> Function({required bool awake}) setAwake,
) {
  var awake = false;
  return states
      .map((state) => state.playing)
      .where((playing) {
        final changed = playing != awake;
        awake = playing;
        return changed;
      })
      .listen((playing) async {
        try {
          await setAwake(awake: playing);
        } on Object catch (error) {
          debugPrint('keepAwakeWhilePlaying: $error');
        }
      });
}

class ScreenAwake {
  static const _channel = MethodChannel('dev.edbrsk.duoscore/screen_awake');

  const ScreenAwake();

  Future<void> set({required bool awake}) async {
    // Only the iOS runner implements this channel.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await _channel.invokeMethod<void>('setAwake', awake);
  }
}
