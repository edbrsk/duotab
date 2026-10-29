import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'playback_cubit.dart';

class TransportBar extends StatelessWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playback = context.read<PlaybackCubit>();
    final playing = context.select<PlaybackCubit, bool>((c) => c.state.playing);
    return ColoredBox(
      color: AppColors.panel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.stop,
              icon: const Icon(Icons.stop),
              onPressed: playback.stop,
            ),
            IconButton(
              tooltip: playing ? l10n.pause : l10n.play,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: playback.playPause,
            ),
          ],
        ),
      ),
    );
  }
}
