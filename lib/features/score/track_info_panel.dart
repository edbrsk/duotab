import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../editor/chord_picker.dart';
import '../editor/cursor_keys.dart';
import '../editor/editor_cubit.dart';
import '../editor/fret_pad.dart';
import '../editor/retune_dialog.dart';
import '../editor/title_dialog.dart';
import '../library/song_list_entry.dart';
import '../playback/playback_cubit.dart';
import '../playback/practice_settings.dart';
import '../playback/tone.dart';
import '../playback/tone_label.dart';
import '../settings/settings_cubit.dart';
import 'score_cubit.dart';

/// The drawn guitar track: name, tuning, string count and tone, and the
/// input that writes on it.
class TrackInfoPanel extends StatelessWidget {
  final bool editable;

  const TrackInfoPanel({this.editable = true, super.key});

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

    if (track == null) {
      return Material(
        type: MaterialType.transparency,
        child: ListView(children: [heading(l10n.trackHeading)]),
      );
    }
    final tuning = track.tuning;
    final details = [
      if (tuning != null) ...[
        heading(l10n.tuning),
        Text(tuningLabel(tuning)),
        Text(l10n.stringsCount(tuning.length)),
        if (editable) ...[
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
    ];

    if (!editable) {
      return Material(
        type: MaterialType.transparency,
        child: ListView(
          children: [
            heading(l10n.trackHeading),
            Text(track.name, style: textTheme.titleMedium),
            ...details,
          ],
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: _SplitPanel(track: track, details: details),
    );
  }
}

/// The track's details over the input, each part scrolling on its own and
/// folding to its header.
class _SplitPanel extends StatelessWidget {
  final TrackSummary track;
  final List<Widget> details;

  const _SplitPanel({required this.track, required this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final settingsCubit = context.read<SettingsCubit>();
    final (detailsFolded, inputFolded, chords) = context
        .select<SettingsCubit, (bool, bool, bool)>(
          (c) => (
            c.state.trackDetailsFolded,
            c.state.inputFolded,
            c.state.chordsShown,
          ),
        );
    final tuning = track.tuning;

    final trackPart = Column(
      key: const Key('track-details'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PartHeader(
          title: Tooltip(
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
              label: Text(
                track.name,
                style: textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          subtitle: detailsFolded && tuning != null
              ? '${tuningLabel(tuning)} · ${l10n.stringsCount(tuning.length)}'
              : null,
          folded: detailsFolded,
          foldTooltip: l10n.hideTrackDetails,
          unfoldTooltip: l10n.showTrackDetails,
          onToggle: () =>
              settingsCubit.setTrackDetailsFolded(folded: !detailsFolded),
        ),
        if (!detailsFolded)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details,
              ),
            ),
          ),
      ],
    );

    final inputHeader = _PartHeader(
      title: Text(
        inputFolded
            ? '${l10n.inputHeading} · ${chords ? l10n.chords : l10n.frets}'
            : l10n.inputHeading,
        style: textTheme.titleSmall,
      ),
      folded: inputFolded,
      foldTooltip: l10n.hideInput,
      unfoldTooltip: l10n.showInput,
      onToggle: () => settingsCubit.setInputFolded(folded: !inputFolded),
    );

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inputFolded)
            Flexible(child: trackPart)
          else
            ConstrainedBox(
              // The input is what's used while writing; folding the track
              // part gives it the rest.
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.4,
              ),
              child: trackPart,
            ),
          const Divider(height: 1),
          if (inputFolded)
            inputHeader
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  inputHeader,
                  const Expanded(
                    child: SingleChildScrollView(child: _PadSwitch()),
                  ),
                  const SizedBox(height: Spacing.sm),
                  const CursorKeys(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PartHeader extends StatelessWidget {
  final Widget title;
  final String? subtitle;
  final bool folded;
  final String foldTooltip;
  final String unfoldTooltip;
  final VoidCallback onToggle;

  const _PartHeader({
    required this.title,
    required this.folded,
    required this.foldTooltip,
    required this.unfoldTooltip,
    required this.onToggle,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            if (subtitle case final subtitle?)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      IconButton(
        tooltip: folded ? unfoldTooltip : foldTooltip,
        icon: Icon(folded ? Icons.chevron_right : Icons.expand_more),
        onPressed: onToggle,
      ),
    ],
  );
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

/// Frets or chords on the pad; the choice is remembered.
class _PadSwitch extends StatelessWidget {
  const _PadSwitch();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chords = context.select<SettingsCubit, bool>(
      (c) => c.state.chordsShown,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          // The panel is narrow beside the vertical bar.
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          ),
          segments: [
            for (final (value, label) in [
              (false, l10n.frets),
              (true, l10n.chords),
            ])
              ButtonSegment(
                value: value,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1, softWrap: false),
                ),
              ),
          ],
          selected: {chords},
          onSelectionChanged: (s) =>
              context.read<SettingsCubit>().setChordsShown(shown: s.single),
        ),
        const SizedBox(height: Spacing.sm),
        if (chords) const ChordPicker() else const FretPad(),
      ],
    );
  }
}
