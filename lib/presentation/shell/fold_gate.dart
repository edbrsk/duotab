import 'package:flutter/material.dart';

import '../../core/duo/hinge_status_provider.dart';
import 'folded_screen.dart';

/// Hides [child] behind [FoldedScreen] while the device is closed. The child
/// stays mounted so its state, and the engine's web view, survive the fold.
class FoldGate extends StatelessWidget {
  final Widget child;

  const FoldGate({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final open = HingeStatusProvider.isOpenOf(context);
    return Stack(
      children: [
        Offstage(
          offstage: !open,
          child: TickerMode(enabled: open, child: child),
        ),
        if (!open) const Positioned.fill(child: FoldedScreen()),
      ],
    );
  }
}
