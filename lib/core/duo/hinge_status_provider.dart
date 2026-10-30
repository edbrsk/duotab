import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Mirrors UIKit's `UIHinge.Status` (iOS 27.1, iPhone Duo), plus
/// [unavailable] for a view hierarchy that reports no hinge.
enum HingeStatus { unknown, closed, partiallyOpen, fullyOpen, unavailable }

class HingeStatusProvider extends ChangeNotifier {
  static const _channel = EventChannel('dev.edbrsk.duoscore/hinge_status');

  StreamSubscription<dynamic>? _subscription;
  HingeStatus _status = HingeStatus.unknown;

  HingeStatusProvider({Stream<dynamic>? hingeEvents}) {
    _subscription = (hingeEvents ?? _platformHingeEvents())?.listen(
      _onHingeEvent,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('HingeStatusProvider: $error');
        _onHingeEvent(null);
      },
    );
  }

  HingeStatus get status => _status;

  /// Only a closed hinge hides the app; an unknown or missing hinge keeps it
  /// usable on simulators and devices that report none.
  bool get isOpen => _status != HingeStatus.closed;

  /// Falls back to open when no provider is above [context].
  static bool isOpenOf(BuildContext context) {
    return context.select<HingeStatusProvider?, bool>(
      (provider) => provider?.isOpen ?? true,
    );
  }

  static Stream<dynamic>? _platformHingeEvents() {
    // Only the iOS runner implements this channel.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    return _channel.receiveBroadcastStream();
  }

  void _onHingeEvent(dynamic event) {
    final status = switch (event) {
      'closed' => HingeStatus.closed,
      'partiallyOpen' => HingeStatus.partiallyOpen,
      'fullyOpen' => HingeStatus.fullyOpen,
      'unavailable' => HingeStatus.unavailable,
      _ => HingeStatus.unknown,
    };
    if (status != _status) {
      _status = status;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
