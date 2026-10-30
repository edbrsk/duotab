import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../editor/editor_cubit.dart';
import '../editor/fret_pad.dart';
import '../editor/retune_dialog.dart';
import '../editor/title_dialog.dart';
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
            Tooltip(
              message: l10n.renameTrack,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () async {
                  final editor = context.read<EditorCubit>();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (_) => TitleDialog(
                      title: track.name,
                      heading: l10n.renameTrack,
                      label: l10n.trackName,
                    ),
                  );
                  if (name != null) await editor.renameTrack(track.index, name);
                },
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.edit, size: IconSizes.md),
                label: Text(track.name, style: textTheme.titleMedium),
              ),
            ),
            if (track.tuning case final tuning?) ...[
              heading(l10n.tuning),
              Text(tuningLabel(tuning)),
              Text(l10n.stringsCount(tuning.length)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () async {
                    final editor = context.read<EditorCubit>();
                    final chosen = await showDialog<RetuneChoice>(
                      context: context,
                      builder: (_) =>
                          RetuneDialog(trackName: track.name, tuning: tuning),
                    );
                    if (chosen != null) {
                      await editor.retune(
                        track.index,
                        chosen.tuning,
                        keepFrets: chosen.keepFrets,
                      );
                    }
                  },
                  child: Text(l10n.retune),
                ),
              ),
              _RetuneReportCard(track: track.index),
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

/// What the last retune of [track] moved or could not place, with ways back.
class _RetuneReportCard extends StatelessWidget {
  final int track;

  const _RetuneReportCard({required this.track});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final report = context.select<EditorCubit, RetuneReport?>(
      (c) => c.state.retune,
    );
    if (report == null ||
        report.track != track ||
        report.moved + report.unplayable == 0) {
      return const SizedBox.shrink();
    }
    final editor = context.read<EditorCubit>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.retuneReport(report.moved, report.unplayable)),
            Wrap(
              children: [
                TextButton(onPressed: editor.undo, child: Text(l10n.undo)),
                // Octaves only shift a retune that keeps the sound.
                if (!report.keepFrets) ...[
                  TextButton(
                    onPressed: report.octave < maxOctave
                        ? () => editor.retuneOctave(1)
                        : null,
                    child: Text(l10n.octaveUp),
                  ),
                  TextButton(
                    onPressed: report.octave > minOctave
                        ? () => editor.retuneOctave(-1)
                        : null,
                    child: Text(l10n.octaveDown),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
