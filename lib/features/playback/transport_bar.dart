import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../score/score_cubit.dart';
import 'playback_cubit.dart';
import 'speed_control.dart';

class TransportBar extends StatefulWidget {
  const TransportBar({super.key});

  @override
  State<TransportBar> createState() => _TransportBarState();
}

class _TransportBarState extends State<TransportBar> {
  final _speedMenu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playback = context.read<PlaybackCubit>();
    final state = context.watch<PlaybackCubit>().state;
    final bars = context.watch<ScoreCubit>().state.song?.bars ?? const [];
    final tempo = state.bar < bars.length
        ? bars[state.bar].tempo * state.practice.speed
        : null;
    final looping = state.practice.looping;
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
              tooltip: state.playing ? l10n.pause : l10n.play,
              icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
              onPressed: playback.playPause,
            ),
            const SizedBox(width: Spacing.sm),
            if (tempo != null)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _speedMenu.open,
                    // Beside the outer screen's bar, large text would not fit.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.tempoMarking(tempo.round())),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            SpeedControl(controller: _speedMenu),
            IconButton(
              tooltip: l10n.loop,
              isSelected: looping,
              icon: const Icon(Icons.repeat),
              color: looping ? AppColors.accent : null,
              onPressed: () => playback.setLooping(on: !looping),
            ),
          ],
        ),
      ),
    );
  }
}
