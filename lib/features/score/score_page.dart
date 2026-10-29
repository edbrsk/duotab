import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/engine_host.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/workspace/workspace_layout.dart';
import '../playback/transport_bar.dart';
import 'score_cubit.dart';
import 'track_drawer.dart';
import 'track_info_panel.dart';

class ScorePage extends StatelessWidget {
  /// Replaces the engine's web view in tests, where no web view can run.
  final Widget? engineView;

  const ScorePage({this.engineView, super.key});

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

    return WorkspaceLayout(
      palette: const SizedBox.shrink(),
      trackPanel: const TrackInfoPanel(),
      transport: const TransportBar(),
      drawer: state.song != null ? const TrackDrawer() : null,
      score: Column(
        children: [
          if (state.song case final song?)
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + Spacing.sm,
                bottom: Spacing.xs,
              ),
              child: Text(
                song.title,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.black87,
                  fontFamily: 'Georgia',
                ),
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
    );
  }
}
