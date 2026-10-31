import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hinge_status_provider.dart';

/// Open, every orientation is allowed again. Returns a function that stops
/// following the hinge.
VoidCallback portraitWhileFolded(
  HingeStatusProvider hinge,
  Future<void> Function(List<DeviceOrientation>) setOrientations,
) {
  var wasOpen = true;
  Future<void> apply() async {
    if (hinge.isOpen == wasOpen) return;
    wasOpen = hinge.isOpen;
    try {
      await setOrientations(
        wasOpen ? const [] : const [DeviceOrientation.portraitUp],
      );
    } on Object catch (error) {
      debugPrint('portraitWhileFolded: $error');
    }
  }

  void onChange() => unawaited(apply());
  hinge.addListener(onChange);
  onChange();
  return () => hinge.removeListener(onChange);
}
