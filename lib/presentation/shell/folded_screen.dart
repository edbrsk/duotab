import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';

class FoldedScreen extends StatelessWidget {
  static const _logoSize = 64.0;
  static const _logoRadius = 16.0;

  const FoldedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Placeholder until the app has a logo.
            Container(
              width: _logoSize,
              height: _logoSize,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(_logoRadius),
              ),
              alignment: Alignment.center,
              child: Text(
                'DT',
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              AppLocalizations.of(context)!.foldedMessage,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
