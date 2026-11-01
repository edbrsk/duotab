import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';

class AppLogoHeader extends StatelessWidget {
  static const _logoSize = 96.0;
  // The iOS app icon's corner, at this size.
  static const _cornerRadius = 22.0;

  const AppLogoHeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
    child: Column(
      children: [
        ClipRRect(
          key: const Key('appLogo'),
          borderRadius: BorderRadius.circular(_cornerRadius),
          child: Image.asset(
            'assets/brand/logo.png',
            width: _logoSize,
            height: _logoSize,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text('DuoScore', style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}
