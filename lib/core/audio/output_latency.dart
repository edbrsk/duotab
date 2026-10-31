import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = EventChannel('dev.edbrsk.duoscore/output_latency');

/// How far the speaker plays behind the app, as iOS reports it for the
/// current route: a few milliseconds on the phone's speaker, far more on
/// Bluetooth headphones. A new value comes with each route change.
Stream<Duration>? outputLatencyEvents() {
  // Only the iOS runner implements this channel.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  return _channel.receiveBroadcastStream().map(
    (seconds) => Duration(
      microseconds: ((seconds as num) * Duration.microsecondsPerSecond).round(),
    ),
  );
}
