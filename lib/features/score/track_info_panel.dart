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
import '../export/export_button.dart';
import '../export/song_exporter.dart';
import '../library/song_list_entry.dart';
import '../playback/playback_cubit.dart';
import '../playback/practice_settings.dart';
import '../playback/tone.dart';
import '../playback/tone_label.dart';
import '../settings/settings_cubit.dart';
import 'score_cubit.dart';

/// The song and its drawn track, over the input that writes on it.
class TrackInfoPanel extends StatelessWidget {
  final bool editable;
  final Future<void> Function(ExportFormat format, Rect anchor)? onExport;

  const TrackInfoPanel({this.editable = true, this.onExport, super.key});

  @override
  Widget build(BuildContext context) {
    final scoreState = context.watch<ScoreCubit>().state;
    final song = scoreState.song;
    if (song == null) return const SizedBox.shrink();
    final track = song.tracks
        .where((t) => t.index == scoreState.selectedTrackIndex)
        .firstOrNull;
    final tab = context.select<SettingsCubit, PanelTab>(
      (c) => c.state.panelTab,
    );
    final body = tab == PanelTab.song
        ? _SongTab(
            // A field's typing belongs to the song it was typed for.
            key: ValueKey(scoreState.path),
            song: song,
            path: scoreState.path,
            editable: editable,
            onExport: onExport,
          )
        : track == null
        ? const SizedBox.shrink()
        : _TrackTab(track: track, editable: editable);

    return Material(
      type: MaterialType.transparency,
      child: editable
          ? _SplitPanel(body: body)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TabSwitch(),
                Expanded(child: SingleChildScrollView(child: body)),
              ],
            ),
    );
  }
}

Widget _heading(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
  child: Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall,
  ),
);

class _TabSwitch extends StatelessWidget {
  const _TabSwitch();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsCubit>();
    final (tab, folded) = context.select<SettingsCubit, (PanelTab, bool)>(
      (c) => (c.state.panelTab, c.state.trackDetailsFolded),
    );
    return SegmentedButton<PanelTab>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      ),
      segments: [
        for (final (value, label) in [
          (PanelTab.song, l10n.song),
          (PanelTab.track, l10n.trackHeading),
        ])
          ButtonSegment(
            value: value,
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
      ],
      selected: {tab},
      onSelectionChanged: (s) {
        settings.setPanelTab(s.single);
        if (folded) settings.setTrackDetailsFolded(folded: false);
      },
    );
  }
}

class _SongTab extends StatelessWidget {
  final SongSummary song;
  final String? path;
  final bool editable;
  final Future<void> Function(ExportFormat format, Rect anchor)? onExport;

  const _SongTab({
    required this.song,
    required this.path,
    required this.editable,
    required this.onExport,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final editor = context.read<EditorCubit>();
    final score = context.read<ScoreCubit>();
    // A field can let go of its text after another song has opened.
    void Function(String) onlyHere(Future<void> Function(String) change) =>
        (text) {
          if (score.state.path == path) change(text);
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context, l10n.information),
        if (!editable) ...[
          Text(song.title, style: textTheme.titleMedium),
          if (song.artist.isNotEmpty) Text(song.artist),
        ] else ...[
          _SongField(
            key: const Key('song-title'),
            label: l10n.songTitle,
            value: song.title,
            allowEmpty: false,
            onCommit: onlyHere(editor.setTitle),
          ),
          const SizedBox(height: Spacing.sm),
          _SongField(
            key: const Key('song-artist'),
            label: l10n.artist,
            value: song.artist,
            allowEmpty: true,
            onCommit: onlyHere(editor.setArtist),
          ),
        ],
        if (onExport case final onExport?) ...[
          _heading(context, l10n.export),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExportButton(
              onExport: onExport,
              canExportPdf: song.guitarTracks.isNotEmpty,
            ),
          ),
        ],
      ],
    );
  }
}

/// Saves on submit or when it lets go of focus, including when it goes away.
class _SongField extends StatefulWidget {
  final String label;
  final String value;
  final bool allowEmpty;
  final void Function(String text) onCommit;

  const _SongField({
    required this.label,
    required this.value,
    required this.allowEmpty,
    required this.onCommit,
    super.key,
  });

  @override
  State<_SongField> createState() => _SongFieldState();
}

class _SongFieldState extends State<_SongField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  /// Submitting also lets go of focus, before the song reports the change.
  String? _sent;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_SongField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      _sent = null;
      if (!_focus.hasFocus) _controller.text = widget.value;
    }
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text == widget.value.trim() || text == _sent) return;
    if (text.isEmpty && !widget.allowEmpty) {
      _controller.text = widget.value;
      return;
    }
    _sent = text;
    widget.onCommit(text);
  }

  @override
  void dispose() {
    _commit();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    textInputAction: TextInputAction.done,
    decoration: InputDecoration(
      labelText: widget.label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
    onSubmitted: (_) => _commit(),
  );
}

class _TrackTab extends StatelessWidget {
  final TrackSummary track;
  final bool editable;

  const _TrackTab({required this.track, required this.editable});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final practice = context.select<PlaybackCubit, TrackPractice>(
      (c) => c.state.practice.tracks[track.index] ?? const TrackPractice(),
    );
    final tuning = track.tuning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, l10n.information),
        if (!editable)
          Text(track.name, style: textTheme.titleMedium)
        else
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
              label: Text(
                track.name,
                style: textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        _heading(context, l10n.musicalNotation),
        _ViewKeys(track: track.index, practice: practice),
        if (tuning != null) ...[
          const SizedBox(height: Spacing.sm),
          Text('${tuningLabel(tuning)} · ${l10n.stringsCount(tuning.length)}'),
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
        _heading(context, l10n.tone),
        DropdownButton<Tone>(
          value: practice.tone,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          onChanged: (tone) {
            if (tone != null) {
              context.read<PlaybackCubit>().setTone(track.index, tone);
            }
          },
          items: [
            for (final tone in Tone.values)
              DropdownMenuItem(value: tone, child: Text(toneLabel(l10n, tone))),
          ],
        ),
      ],
    );
  }
}

/// Guitar Pro's four views of a track.
class _ViewKeys extends StatelessWidget {
  final int track;
  final TrackPractice practice;

  const _ViewKeys({required this.track, required this.practice});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = practice;
    void send({bool? notation, bool? tab, bool? slash, bool? numbered}) =>
        context.read<PlaybackCubit>().setStaffView(
          track,
          notation: notation ?? p.showNotation,
          tab: tab ?? p.showTab,
          slash: slash ?? p.showSlash,
          numbered: numbered ?? p.showNumbered,
        );
    // The cursor and taps work on the standard and tab staves.
    final keys = [
      (
        l10n.viewStandard,
        l10n.standardNotation,
        p.showNotation,
        p.showNotation && !p.showTab
            ? null
            : () => send(notation: !p.showNotation),
      ),
      (
        l10n.tab,
        l10n.tablature,
        p.showTab,
        p.showTab && !p.showNotation ? null : () => send(tab: !p.showTab),
      ),
      (
        l10n.viewSlash,
        l10n.slashNotation,
        p.showSlash,
        () => send(slash: !p.showSlash),
      ),
      (
        l10n.viewNumbered,
        l10n.numberedNotation,
        p.showNumbered,
        () => send(numbered: !p.showNumbered),
      ),
    ];
    return Row(
      children: [
        for (final (i, (label, tooltip, on, onTap)) in keys.indexed) ...[
          if (i > 0) const SizedBox(width: Spacing.xs),
          Expanded(
            child: Tooltip(
              message: tooltip,
              child: Material(
                key: on ? const Key('view-selected') : null,
                color: on ? AppColors.accent : AppColors.key,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onTap,
                  child: SizedBox(
                    height: AccessibleSizes.minTouchTarget,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label, maxLines: 1, softWrap: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The song or track over the input, each part scrolling on its own and
/// folding to its header.
class _SplitPanel extends StatelessWidget {
  final Widget body;

  const _SplitPanel({required this.body});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final settingsCubit = context.read<SettingsCubit>();
    final (detailsFolded, inputFolded) = context
        .select<SettingsCubit, (bool, bool)>(
          (c) => (c.state.trackDetailsFolded, c.state.inputFolded),
        );

    final upperPart = Column(
      key: const Key('track-details'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PartHeader(
          title: const _TabSwitch(),
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
              child: body,
            ),
          ),
      ],
    );

    final inputHeader = _PartHeader(
      title: Text(l10n.inputHeading, style: textTheme.titleMedium),
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
            Flexible(child: upperPart)
          else
            ConstrainedBox(
              // The input is what's used while writing; folding the track
              // part gives it the rest.
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.4,
              ),
              child: upperPart,
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
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: title),
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
