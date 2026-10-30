import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/engine_host.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/workspace/workspace_layout.dart';
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

class ScorePage extends StatelessWidget {
  /// Replaces the engine's web view in tests, where no web view can run.
  final Widget? engineView;

  /// Shows the Export button beside the title.
  final Future<void> Function(ExportFormat format, Rect anchor)? onExport;

  const ScorePage({this.engineView, this.onExport, super.key});

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
      child: WorkspaceLayout(
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
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + Spacing.sm,
                  bottom: Spacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Tooltip(
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
                          label: Text(
                            song.title,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.black87,
                              fontFamily: 'Georgia',
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onExport case final onExport?)
                      ExportButton(
                        onExport: onExport,
                        canExportPdf: song.guitarTracks.isNotEmpty,
                      ),
                  ],
                ),
              ),
            Expanded(
              // The engine stays mounted even with nothing to show: it also
              // answers the library's requests.
              child: Stack(
                children: [
                  Offstage(
                    offstage: message != null,
                    child: engineView ?? const EngineView(),
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
    );
  }
}
