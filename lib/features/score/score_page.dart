import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../core/duo/vertical_bar_edge_provider.dart';
import '../../engine/engine_host.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/shell/app_destinations.dart';
import '../../presentation/shell/bar_actions.dart';
import '../../presentation/workspace/workspace_layout.dart';
import '../editor/edit_failure.dart';
import '../editor/editor_cubit.dart';
import '../editor/palette.dart';
import '../editor/title_dialog.dart';
import '../export/export_button.dart';
import '../export/song_exporter.dart';
import '../playback/transport_bar.dart';
import '../settings/settings_cubit.dart';
import 'score_cubit.dart';
import 'track_drawer.dart';
import 'track_info_panel.dart';

class ScorePage extends StatefulWidget {
  /// Replaces the engine's web view in tests, where no web view can run.
  final Widget? engineView;

  /// Shows the Export button beside the title.
  final Future<void> Function(ExportFormat format, Rect anchor)? onExport;

  const ScorePage({this.engineView, this.onExport, super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  var _playOnlyPanelOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playOnly = WorkspaceLayout.isCollapsed(context);
    context.read<EditorCubit>().placesOnTap = !playOnly;
    // Wider, the panel is a side panel again.
    if (!playOnly) _playOnlyPanelOpen = false;
  }

  void _togglePlayOnlyPanel() =>
      setState(() => _playOnlyPanelOpen = !_playOnlyPanelOpen);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<ScoreCubit>().state;
    final message = switch (state) {
      ScoreState(:final error?) => l10n.scoreError(error),
      ScoreState(song: null, loading: false) => l10n.noSongOpen,
      ScoreState(:final song?) when song.guitarTracks.isEmpty =>
        l10n.noGuitarTrack,
      _ => null,
    };
    final textTheme = Theme.of(context).textTheme;
    final collapsed = context.select<SettingsCubit, bool>(
      (c) => c.state.trackPanelCollapsed,
    );
    final paletteCollapsed = context.select<SettingsCubit, bool>(
      (c) => c.state.paletteCollapsed,
    );
    final playOnly = WorkspaceLayout.isCollapsed(context);
    final hasPlayOnlyPanel = playOnly && state.song != null;
    final panelOpen = hasPlayOnlyPanel && _playOnlyPanelOpen;
    final edge = VerticalBarEdgeProvider.edgeOf(context);
    final hasBar = edge != VerticalBarEdge.unspecified;
    final panelButton = BarAction(
      icon: panelOpen ? Icons.close : Icons.menu,
      tooltip: panelOpen ? l10n.hideTrackPanel : l10n.showTrackPanel,
      onPressed: _togglePlayOnlyPanel,
    );

    return BlocListener<ScoreCubit, ScoreState>(
      // Once per opened song: edits replace the song but keep its openId.
      listenWhen: (before, after) =>
          after.openId != before.openId &&
          (after.song?.unplayableNotes ?? 0) > 0,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unplayableOnOpen(state.song!.unplayableNotes)),
        ),
      ),
      child: BarActionsFor(
        tab: AppTab.editor,
        actions: hasPlayOnlyPanel && hasBar ? [panelButton] : const [],
        child: _EditFailures(
          child: Stack(
            fit: StackFit.expand,
            children: [
              WorkspaceLayout(
                palette: state.song != null ? const Palette() : null,
                paletteCollapsed: paletteCollapsed,
                onTogglePalette: () => context
                    .read<SettingsCubit>()
                    .setPaletteCollapsed(collapsed: !paletteCollapsed),
                trackPanel: const TrackInfoPanel(),
                trackPanelCollapsed: collapsed,
                onToggleTrackPanel: () => context
                    .read<SettingsCubit>()
                    .setTrackPanelCollapsed(collapsed: !collapsed),
                transport: state.song != null ? const TransportBar() : null,
                drawer: state.song != null ? const TrackDrawer() : null,
                score: Column(
                  children: [
                    if (state.song case final song?)
                      _TitleRow(
                        song: song,
                        editable: !playOnly,
                        onExport: widget.onExport,
                        panelButton: hasPlayOnlyPanel && !hasBar && !panelOpen
                            ? _PanelButton(action: panelButton)
                            : null,
                      ),
                    Expanded(
                      // The engine stays mounted even with nothing to show:
                      // it also answers the library's requests.
                      child: Stack(
                        children: [
                          Offstage(
                            offstage: message != null,
                            child: widget.engineView ?? const EngineView(),
                          ),
                          if (message != null)
                            Center(
                              child: Text(
                                message,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          if (state.loading) const LinearProgressIndicator(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPlayOnlyPanel)
                Positioned.fill(
                  child: _PanelTransition(
                    fromLeft:
                        (edge == VerticalBarEdge.leading) !=
                        (Directionality.of(context) == TextDirection.rtl),
                    child: panelOpen
                        ? _PlayOnlyPanel(
                            closeButton: hasBar
                                ? null
                                : _PanelButton(action: panelButton),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final SongSummary song;
  final bool editable;
  final Future<void> Function(ExportFormat format, Rect anchor)? onExport;
  final Widget? panelButton;

  const _TitleRow({
    required this.song,
    required this.editable,
    required this.onExport,
    required this.panelButton,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: Colors.black87, fontFamily: 'Georgia');
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + Spacing.sm,
        bottom: Spacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: !editable
                ? Text(song.title, style: style)
                : Tooltip(
                    message: l10n.changeTitle,
                    child: TextButton.icon(
                      onPressed: () async {
                        final editor = context.read<EditorCubit>();
                        final title = await showDialog<String>(
                          context: context,
                          builder: (_) => TitleDialog(title: song.title),
                        );
                        if (title != null) await editor.setTitle(title);
                      },
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.edit, color: Colors.black38),
                      label: Text(song.title, style: style),
                    ),
                  ),
          ),
          if (onExport case final onExport?)
            ExportButton(
              onExport: onExport,
              canExportPdf: song.guitarTracks.isNotEmpty,
            ),
          ?panelButton,
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  final BarAction action;

  const _PanelButton({required this.action});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: action.tooltip,
    onPressed: action.onPressed,
    icon: Icon(action.icon),
  );
}

/// Slides the panel in from the side its button is on, and back out.
class _PanelTransition extends StatelessWidget {
  static const _duration = Duration(milliseconds: 220);
  static const _slide = 0.12;

  final bool fromLeft;
  final Widget? child;

  const _PanelTransition({required this.fromLeft, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _duration,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => SlideTransition(
      position: Tween(
        begin: Offset(fromLeft ? -_slide : _slide, 0),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

class _PlayOnlyPanel extends StatelessWidget {
  /// Shown when no vertical bar carries the button.
  final Widget? closeButton;

  const _PlayOnlyPanel({this.closeButton});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      key: const Key('playOnlyPanel'),
      color: AppColors.panel,
      child: Padding(
        padding: EdgeInsets.only(
          left: padding.left + Spacing.md,
          right: padding.right + Spacing.md,
          top: padding.top + Spacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (closeButton case final closeButton?)
              Align(alignment: Alignment.centerRight, child: closeButton),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                removeTop: true,
                removeRight: true,
                child: const TrackInfoPanel(editable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says why an edit the engine refused didn't happen.
class _EditFailures extends StatefulWidget {
  final Widget child;

  const _EditFailures({required this.child});

  @override
  State<_EditFailures> createState() => _EditFailuresState();
}

class _EditFailuresState extends State<_EditFailures> {
  late final StreamSubscription<String> _failures;

  @override
  void initState() {
    super.initState();
    _failures = context.read<EditorCubit>().failures.listen((message) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(editFailureMessage(l10n, message))),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_failures.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
