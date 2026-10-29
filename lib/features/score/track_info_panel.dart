import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../editor/fret_pad.dart';
import '../library/song_list_entry.dart';
import '../playback/playback_cubit.dart';
import '../playback/practice_settings.dart';
import '../playback/tone.dart';
import '../playback/tone_label.dart';
import 'score_cubit.dart';

/// The drawn guitar track: name, tuning, string count and tone.
class TrackInfoPanel extends StatelessWidget {
  const TrackInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scoreState = context.watch<ScoreCubit>().state;
    final track = scoreState.song?.tracks
        .where((t) => t.index == scoreState.selectedTrackIndex)
        .firstOrNull;
    final practice = context.select<PlaybackCubit, TrackPractice>(
      (c) =>
          (track == null ? null : c.state.practice.tracks[track.index]) ??
          const TrackPractice(),
    );
    final tone = practice.tone;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
      child: Text(text.toUpperCase(), style: textTheme.labelSmall),
    );

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        children: [
          heading(l10n.trackHeading),
          if (track != null) ...[
            Text(track.name, style: textTheme.titleMedium),
            if (track.tuning case final tuning?) ...[
              heading(l10n.tuning),
              Text(tuningLabel(tuning)),
              Text(l10n.stringsCount(tuning.length)),
            ],
            heading(l10n.notation),
            Wrap(
              spacing: Spacing.xs,
              children: [
                FilterChip(
                  label: Text(l10n.standardNotation),
                  selected: practice.showNotation,
                  // At least one staff stays drawn.
                  onSelected: practice.showNotation && !practice.showTab
                      ? null
                      : (on) => context.read<PlaybackCubit>().setStaffView(
                          track.index,
                          notation: on,
                          tab: practice.showTab,
                        ),
                ),
                FilterChip(
                  label: Text(l10n.tab),
                  selected: practice.showTab,
                  onSelected: practice.showTab && !practice.showNotation
                      ? null
                      : (on) => context.read<PlaybackCubit>().setStaffView(
                          track.index,
                          notation: practice.showNotation,
                          tab: on,
                        ),
                ),
              ],
            ),
            heading(l10n.tone),
            RadioGroup<Tone>(
              groupValue: tone,
              onChanged: (value) {
                if (value != null) {
                  context.read<PlaybackCubit>().setTone(track.index, value);
                }
              },
              child: Column(
                children: [
                  for (final t in Tone.values)
                    RadioListTile<Tone>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: t,
                      title: Text(toneLabel(l10n, t)),
                    ),
                ],
              ),
            ),
            heading(l10n.fret),
            const FretPad(),
          ],
        ],
      ),
    );
  }
}
