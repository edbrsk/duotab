import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shell/app_destinations.dart';
import 'glass_capsule.dart';

/// Icon-only tabs on a floating glass capsule, for the iPhone Duo's vertical
/// bar.
class AppNavigationRail extends StatelessWidget {
  static const _selectedFillOpacity = 0.08;

  final AppTab currentTab;
  final ValueChanged<AppTab> onTap;

  const AppNavigationRail({
    required this.currentTab,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context)!.navigationLabel,
      child: GlassCapsule(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final destination in appDestinations(context))
              IconButton(
                // Labels are hidden, so the tooltip names the tab on long press.
                tooltip: destination.label,
                onPressed: () => onTap(destination.tab),
                iconSize: IconSizes.md,
                constraints: const BoxConstraints(
                  minWidth: AccessibleSizes.minTouchTarget,
                  minHeight: AccessibleSizes.minTouchTarget,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: destination.tab == currentTab
                      ? AppColors.accent
                      : colorScheme.onSurfaceVariant,
                  backgroundColor: destination.tab == currentTab
                      ? colorScheme.onSurface.withValues(
                          alpha: _selectedFillOpacity,
                        )
                      : null,
                ),
                icon: Icon(
                  destination.tab == currentTab
                      ? destination.selectedIcon
                      : destination.icon,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
