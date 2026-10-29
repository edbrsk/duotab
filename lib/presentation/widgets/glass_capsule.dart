import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';

/// Frosted, stadium-shaped surface for controls floating in the iPhone Duo's
/// vertical bar.
class GlassCapsule extends StatelessWidget {
  static const _blurSigma = 20.0;
  static const _surfaceOpacity = 0.72;
  static const _borderOpacity = 0.4;
  static const _shadowOpacity = 0.08;

  /// Inner padding around [child].
  static const padding = Spacing.xs;

  final Widget child;

  const GlassCapsule({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: _borderOpacity),
          ),
        ),
        shadows: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: _shadowOpacity),
            blurRadius: Spacing.md,
            offset: const Offset(0, Spacing.xs),
          ),
        ],
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: StadiumBorder()),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: ColoredBox(
            color: colorScheme.surface.withValues(alpha: _surfaceOpacity),
            child: Padding(
              padding: const EdgeInsets.all(padding),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
