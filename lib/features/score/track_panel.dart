import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'score_cubit.dart';

class TrackPanel extends StatelessWidget {
  const TrackPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScoreCubit>().state;
    final tracks = state.song?.guitarTracks ?? const [];
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text(
              AppLocalizations.of(context)!.tracksHeading.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final track in tracks)
            ListTile(
              dense: true,
              title: Text(track.name),
              selected: track.index == state.selectedTrackIndex,
              selectedColor: AppColors.accent,
              onTap: () => context.read<ScoreCubit>().selectTrack(track.index),
            ),
        ],
      ),
    );
  }
}
