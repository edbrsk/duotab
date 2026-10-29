import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';

const kSidePanelWidth = 220.0;
const kThreeColumnMinWidth = 720.0;

/// Palette | score | track panel, with the score centred on the whole screen.
/// Side panels run to the screen edge so the iPhone Duo's vertical bar sits
/// on the panel's own colour; their content stays clear of it.
class WorkspaceLayout extends StatelessWidget {
  final Widget palette;
  final Widget score;
  final Widget trackPanel;
  final Widget? transport;

  /// Under [transport], in the score column.
  final Widget? drawer;

  const WorkspaceLayout({
    required this.palette,
    required this.score,
    required this.trackPanel,
    this.transport,
    this.drawer,
    super.key,
  });

  static bool isCollapsed(BuildContext context) =>
      MediaQuery.sizeOf(context).width < kThreeColumnMinWidth;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final scoreColumn = Column(
      children: [
        if (isCollapsed(context)) const _WiderToEditBanner(),
        Expanded(
          child: ColoredBox(
            color: AppColors.paper,
            child: SizedBox.expand(key: const Key('score'), child: score),
          ),
        ),
        ?transport,
        ?drawer,
      ],
    );

    if (isCollapsed(context)) return scoreColumn;

    return Row(
      children: [
        _SidePanel(
          contentKey: const Key('palette'),
          insets: EdgeInsets.only(
            left: padding.left,
            top: padding.top,
            bottom: padding.bottom,
          ),
          child: palette,
        ),
        Expanded(child: scoreColumn),
        _SidePanel(
          contentKey: const Key('trackPanel'),
          insets: EdgeInsets.only(
            right: padding.right,
            top: padding.top,
            bottom: padding.bottom,
          ),
          child: trackPanel,
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  final Key contentKey;
  final EdgeInsets insets;
  final Widget child;

  const _SidePanel({
    required this.contentKey,
    required this.insets,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kSidePanelWidth,
      child: ColoredBox(
        color: AppColors.panel,
        child: Padding(
          padding: insets.add(const EdgeInsets.all(Spacing.sm)),
          // The insets are applied here; without this, ListTile and other
          // safe-area-aware children would apply them a second time.
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeTop: true,
            removeRight: true,
            removeBottom: true,
            child: SizedBox.expand(key: contentKey, child: child),
          ),
        ),
      ),
    );
  }
}

class _WiderToEditBanner extends StatelessWidget {
  const _WiderToEditBanner();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.panel,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + Spacing.sm,
          bottom: Spacing.sm,
          left: Spacing.md,
          right: Spacing.md,
        ),
        child: Row(
          children: [
            const Icon(Icons.open_in_full, size: IconSizes.md),
            const SizedBox(width: Spacing.sm),
            Expanded(child: Text(AppLocalizations.of(context)!.widerToEdit)),
          ],
        ),
      ),
    );
  }
}
