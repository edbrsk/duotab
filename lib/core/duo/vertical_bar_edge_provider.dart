import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Mirrors UIKit's `UITraitCollection.verticalBarEdge` (iOS 27.1, iPhone Duo).
enum VerticalBarEdge { unspecified, leading, trailing }

class VerticalBarEdgeProvider extends ChangeNotifier {
  static const _channel = EventChannel('me.withedgar.duotab/vertical_bar_edge');

  StreamSubscription<dynamic>? _subscription;
  VerticalBarEdge _edge = VerticalBarEdge.unspecified;

  VerticalBarEdgeProvider({Stream<dynamic>? edgeEvents}) {
    _subscription = (edgeEvents ?? _platformEdgeEvents())?.listen(
      _onEdgeEvent,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('VerticalBarEdgeProvider: $error');
        _onEdgeEvent(null);
      },
    );
  }

  VerticalBarEdge get edge => _edge;

  /// Falls back to [VerticalBarEdge.unspecified] when no provider is above
  /// [context], so widgets keep their bottom-bar layout in isolation.
  static VerticalBarEdge edgeOf(BuildContext context) {
    return context.select<VerticalBarEdgeProvider?, VerticalBarEdge>(
      (provider) => provider?.edge ?? VerticalBarEdge.unspecified,
    );
  }

  /// [edgeOf] for use outside `build`, such as in a tap handler.
  static VerticalBarEdge readEdge(BuildContext context) =>
      Provider.of<VerticalBarEdgeProvider?>(context, listen: false)?.edge ??
      VerticalBarEdge.unspecified;

  static Stream<dynamic>? _platformEdgeEvents() {
    // Only the iOS runner implements this channel.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    return _channel.receiveBroadcastStream();
  }

  void _onEdgeEvent(dynamic event) {
    final edge = switch (event) {
      'leading' => VerticalBarEdge.leading,
      'trailing' => VerticalBarEdge.trailing,
      _ => VerticalBarEdge.unspecified,
    };
    if (edge != _edge) {
      _edge = edge;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
