import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../core/duo/hinge_status_provider.dart';
import '../../l10n/app_localizations.dart';

// Wide enough for three 44 pt fret keys beside the vertical bar.
const kSidePanelWidth = 240.0;
const kThreeColumnMinWidth = 720.0;

/// A collapsed panel's strip, not counting the vertical bar under it.
const kCollapsedPanelWidth = AccessibleSizes.minTouchTarget + Spacing.xs;

/// Palette | score | track panel, with the score centred on the whole screen.
/// Side panels run to the screen edge so the iPhone Duo's vertical bar sits
/// on the panel's own colour; their content stays clear of it.
class WorkspaceLayout extends StatefulWidget {
  /// Null until the editor gives the palette its tools.
  final Widget? palette;
  final bool paletteCollapsed;
  final VoidCallback? onTogglePalette;
  final Widget score;
  final Widget trackPanel;
  final bool trackPanelCollapsed;
  final VoidCallback? onToggleTrackPanel;
  final Widget? transport;

  /// Under [transport], in the score column.
  final Widget? drawer;

  const WorkspaceLayout({
    required this.score,
    required this.trackPanel,
    this.palette,
    this.paletteCollapsed = false,
    this.onTogglePalette,
    this.trackPanelCollapsed = false,
    this.onToggleTrackPanel,
    this.transport,
    this.drawer,
    super.key,
  });

  static bool isCollapsed(BuildContext context) =>
      MediaQuery.sizeOf(context).width < kThreeColumnMinWidth;

  @override
  State<WorkspaceLayout> createState() => _WorkspaceLayoutState();
}

class _WorkspaceLayoutState extends State<WorkspaceLayout> {
  // The column moves between a Row and a lone Padding as the layout
  // collapses; without the key, the drawer and the sheet would be rebuilt.
  final _scoreColumnKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final collapsed = WorkspaceLayout.isCollapsed(context);
    final scoreColumn = Column(
      key: _scoreColumnKey,
      children: [
        if (collapsed) const _WiderToEditBanner(),
        Expanded(
          child: ColoredBox(
            color: AppColors.paper,
            child: SizedBox.expand(
              key: const Key('score'),
              child: widget.score,
            ),
          ),
        ),
        ?widget.transport,
        ?widget.drawer,
      ],
    );

    // With no side panel to sit on, the score keeps clear of the bar, which
    // still sits on the panel colour.
    if (collapsed) {
      return ColoredBox(
        color: AppColors.panel,
        child: Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: scoreColumn,
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        if (widget.palette case final palette?)
          _SidePanel(
            contentKey: const Key('palette'),
            insets: EdgeInsets.only(
              left: padding.left,
              top: padding.top,
              bottom: padding.bottom,
            ),
            leading: true,
            collapsed: widget.paletteCollapsed,
            toggle: widget.onTogglePalette == null
                ? null
                : _PanelToggle(
                    collapseTooltip: l10n.hidePalette,
                    expandTooltip: l10n.showPalette,
                    collapseIcon: Icons.keyboard_double_arrow_left,
                    expandIcon: Icons.keyboard_double_arrow_right,
                    onPressed: widget.onTogglePalette!,
                  ),
            child: palette,
          )
        else if (padding.left > 0)
          // The vertical bar keeps a panel colour under it, never the sheet's.
          ColoredBox(
            key: const Key('barStrip'),
            color: AppColors.panel,
            child: SizedBox(width: padding.left, height: double.infinity),
          ),
        Expanded(child: scoreColumn),
        _SidePanel(
          contentKey: const Key('trackPanel'),
          insets: EdgeInsets.only(
            right: padding.right,
            top: padding.top,
            bottom: padding.bottom,
          ),
          collapsed: widget.trackPanelCollapsed,
          toggle: widget.onToggleTrackPanel == null
              ? null
              : _PanelToggle(
                  collapseTooltip: l10n.hideTrackPanel,
                  expandTooltip: l10n.showTrackPanel,
                  collapseIcon: Icons.keyboard_double_arrow_right,
                  expandIcon: Icons.keyboard_double_arrow_left,
                  onPressed: widget.onToggleTrackPanel!,
                ),
          child: widget.trackPanel,
        ),
      ],
    );
  }
}

class _PanelToggle {
  final String collapseTooltip;
  final String expandTooltip;
  final IconData collapseIcon;
  final IconData expandIcon;
  final VoidCallback onPressed;

  const _PanelToggle({
    required this.collapseTooltip,
    required this.expandTooltip,
    required this.collapseIcon,
    required this.expandIcon,
    required this.onPressed,
  });

  Widget button({required bool collapsed}) => IconButton(
    tooltip: collapsed ? expandTooltip : collapseTooltip,
    icon: Icon(collapsed ? expandIcon : collapseIcon),
    onPressed: onPressed,
  );
}

class _SidePanel extends StatelessWidget {
  final Key contentKey;
  final EdgeInsets insets;
  final bool collapsed;
  final _PanelToggle? toggle;
  final Widget child;

  /// The palette's side; its toggle sits at the outer, leading edge.
  final bool leading;

  const _SidePanel({
    required this.contentKey,
    required this.insets,
    required this.child,
    this.collapsed = false,
    this.toggle,
    this.leading = false,
  });

  @override
  Widget build(BuildContext context) {
    final toggle = this.toggle;
    return SizedBox(
      width: collapsed
          ? kCollapsedPanelWidth + insets.horizontal
          : kSidePanelWidth,
      child: ColoredBox(
        color: AppColors.panel,
        child: Padding(
          // A collapsed strip is only its button, kept against the bar.
          padding: insets.add(
            collapsed && toggle != null
                ? EdgeInsets.only(
                    left: leading ? 0 : Spacing.xs,
                    right: leading ? Spacing.xs : 0,
                    top: Spacing.sm,
                  )
                : const EdgeInsets.all(Spacing.sm),
          ),
          child: collapsed && toggle != null
              ? Align(
                  alignment: leading ? Alignment.topLeft : Alignment.topRight,
                  child: toggle.button(collapsed: true),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (toggle != null)
                      Align(
                        alignment: leading
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: toggle.button(collapsed: false),
                      ),
                    Expanded(
                      // The insets are applied here; without this, ListTile
                      // and other safe-area-aware children would apply them a
                      // second time.
                      child: MediaQuery.removePadding(
                        context: context,
                        removeLeft: true,
                        removeTop: true,
                        removeRight: true,
                        removeBottom: true,
                        child: SizedBox.expand(key: contentKey, child: child),
                      ),
                    ),
                  ],
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
    final l10n = AppLocalizations.of(context)!;
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
            Expanded(
              child: Text(
                HingeStatusProvider.isOpenOf(context)
                    ? l10n.widerToEdit
                    : l10n.openToEdit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
