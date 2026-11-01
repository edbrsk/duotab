import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/workspace/workspace_layout.dart';
import '../editor/editor_cubit.dart';
import '../playback/mix_level.dart';
import '../playback/playback_cubit.dart';
import '../playback/practice_settings.dart';
import '../settings/settings_cubit.dart';
import 'add_track_dialog.dart';
import 'mixer_row.dart';
import 'score_cubit.dart';

const kTrackRowHeight = 48.0;
const kBarCellWidth = 14.0;
const kTrackColumnWidth = 228.0;
const kDrawerMaxHeightFraction = 0.4;
const _headerHeight = AccessibleSizes.minTouchTarget;
const _sectionRowHeight = 20.0;

/// Guitar Pro's track list: every track with mute and solo, beside a grid
/// of bars that shows where each track plays and jumps playback there.
class TrackDrawer extends StatefulWidget {
  const TrackDrawer({super.key});

  @override
  State<TrackDrawer> createState() => _TrackDrawerState();
}

class _TrackDrawerState extends State<TrackDrawer> {
  final _grid = ScrollController();
  var _expanded = true;
  var _mixer = false;
  int? _revealedBar;

  /// Set while the mixer shows, to turn its meters off when the drawer goes.
  PlaybackCubit? _metering;

  void _toggleMixer() {
    setState(() => _mixer = !_mixer);
    final playback = context.read<PlaybackCubit>();
    _metering = _mixer ? playback : null;
    unawaited(playback.showMeters(on: _mixer));
  }

  @override
  void dispose() {
    if (_metering case final playback?) {
      unawaited(playback.showMeters(on: false));
    }
    _grid.dispose();
    super.dispose();
  }

  void _reveal(int bar) {
    if (!_grid.hasClients) return;
    final position = _grid.position;
    final x = bar * kBarCellWidth;
    final visible =
        x >= position.pixels &&
        x + kBarCellWidth <= position.pixels + position.viewportDimension;
    if (visible) return;
    _grid.animateTo(
      (x - position.viewportDimension / 3).clamp(0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _tapCell(TrackSummary track, int bar, int? drawn) async {
    if (track.kind == TrackKind.guitar && track.index != drawn) {
      await context.read<ScoreCubit>().selectTrack(track.index);
    }
    if (mounted) await context.read<PlaybackCubit>().seekBar(bar);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scoreState = context.watch<ScoreCubit>().state;
    final song = scoreState.song;
    if (song == null || song.tracks.isEmpty) return const SizedBox.shrink();
    final playback = context.watch<PlaybackCubit>().state;
    final drawn = scoreState.selectedTrackIndex;
    final rows = song.tracks;
    final barCount = song.bars.length;
    final maxBody =
        MediaQuery.sizeOf(context).height * kDrawerMaxHeightFraction -
        _headerHeight;
    // The mixer's Master row stands where the grid has its sections.
    final bodyHeight = min(
      rows.length * kTrackRowHeight +
          (_mixer ? kTrackRowHeight : _sectionRowHeight),
      maxBody,
    );

    if (playback.bar != _revealedBar) {
      _revealedBar = playback.bar;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(playback.bar),
      );
    }

    return ColoredBox(
      color: AppColors.panel,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: Spacing.md),
                  Text(
                    l10n.tracksHeading.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  // Split View is a player: editing waits for a wider window.
                  if (!WorkspaceLayout.isCollapsed(context))
                    IconButton(
                      tooltip: l10n.addTrack,
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final editor = context.read<EditorCubit>();
                        final score = context.read<ScoreCubit>().state;
                        final tone = context
                            .read<SettingsCubit>()
                            .state
                            .defaultTone;
                        final drawn = score.song?.tracks
                            .where((t) => t.index == score.selectedTrackIndex)
                            .firstOrNull;
                        final tuning = await showDialog<List<int>>(
                          context: context,
                          builder: (_) => AddTrackDialog(tuning: drawn?.tuning),
                        );
                        if (tuning != null) {
                          await editor.addTrack(tuning, tone.program);
                        }
                      },
                    ),
                  IconButton(
                    tooltip: l10n.mixer,
                    isSelected: _mixer,
                    icon: const Icon(Icons.tune),
                    onPressed: _toggleMixer,
                  ),
                  IconButton(
                    key: const Key('drawerToggle'),
                    tooltip: _expanded ? l10n.hideTracks : l10n.showTracks,
                    icon: Icon(
                      _expanded ? Icons.expand_more : Icons.expand_less,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),
            if (_expanded)
              SizedBox(
                height: bodyHeight,
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        // Play-only rows have no track menu to make room for.
                        width: WorkspaceLayout.isCollapsed(context)
                            ? kTrackColumnWidth - AccessibleSizes.minTouchTarget
                            : kTrackColumnWidth,
                        child: Column(
                          children: [
                            for (final track in rows)
                              _TrackRow(
                                key: ValueKey('trackRow-${track.index}'),
                                track: track,
                                drawn: track.index == drawn,
                                practice:
                                    playback.practice.tracks[track.index] ??
                                    const TrackPractice(),
                                song: song,
                              ),
                            if (_mixer)
                              SizedBox(
                                height: kTrackRowHeight,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: Spacing.md,
                                    ),
                                    child: Text(l10n.master),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_mixer)
                        Expanded(
                          child: Column(
                            children: [
                              for (final track in rows)
                                MixerRow(
                                  key: ValueKey('mixerRow-${track.index}'),
                                  track: track,
                                  volumeDb:
                                      playback
                                          .practice
                                          .tracks[track.index]
                                          ?.volumeDb ??
                                      snapDb(track.volumeDb),
                                  pan:
                                      playback
                                          .practice
                                          .tracks[track.index]
                                          ?.pan ??
                                      track.pan,
                                ),
                              MasterRow(
                                volumeDb:
                                    playback.practice.masterDb ??
                                    snapDb(song.masterDb),
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            key: const Key('barGrid'),
                            controller: _grid,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: barCount * kBarCellWidth,
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      for (final track in rows)
                                        GestureDetector(
                                          key: ValueKey(
                                            'barRow-${track.index}',
                                          ),
                                          onTapUp: (details) => _tapCell(
                                            track,
                                            (details.localPosition.dx ~/
                                                    kBarCellWidth)
                                                .clamp(0, barCount - 1),
                                            drawn,
                                          ),
                                          child: CustomPaint(
                                            size: Size(
                                              barCount * kBarCellWidth,
                                              kTrackRowHeight,
                                            ),
                                            painter: _BarRowPainter(
                                              barsWithNotes:
                                                  track.barsWithNotes,
                                              color: track.index == drawn
                                                  ? AppColors.accent
                                                  : Colors.white38,
                                            ),
                                          ),
                                        ),
                                      _SectionRow(bars: song.bars),
                                    ],
                                  ),
                                  Positioned(
                                    key: const Key('currentBarMarker'),
                                    left: playback.bar * kBarCellWidth,
                                    top: 0,
                                    bottom: 0,
                                    width: 2,
                                    child: const ColoredBox(
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final TrackSummary track;
  final bool drawn;
  final TrackPractice practice;
  final SongSummary song;

  const _TrackRow({
    required this.track,
    required this.drawn,
    required this.practice,
    required this.song,
    super.key,
  });

  Future<void> _remove(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeTrackQuestion(track.name)),
        content: Text(l10n.removeTrackBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) await editor.removeTrack(track.index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playback = context.read<PlaybackCubit>();
    return SizedBox(
      height: kTrackRowHeight,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: track.kind == TrackKind.guitar
                  ? () => context.read<ScoreCubit>().selectTrack(track.index)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: drawn ? AppColors.accent : null),
                  ),
                ),
              ),
            ),
          ),
          _MixToggle(
            label: l10n.muteShort,
            tooltip: l10n.muteTrack(track.name),
            active: practice.mute,
            onPressed: () => playback.setMute(track.index, on: !practice.mute),
          ),
          _MixToggle(
            label: l10n.soloShort,
            tooltip: l10n.soloTrack(track.name),
            active: practice.solo,
            onPressed: () => playback.setSolo(track.index, on: !practice.solo),
          ),
          if (track.kind == TrackKind.guitar &&
              !WorkspaceLayout.isCollapsed(context))
            PopupMenuButton<VoidCallback>(
              tooltip: l10n.trackActions,
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => action(),
              itemBuilder: (context) {
                final editor = context.read<EditorCubit>();
                final last = song.tracks.length - 1;
                final guitars = song.guitarTracks.length;
                return [
                  PopupMenuItem(
                    value: () => editor.moveTrack(track.index, track.index - 1),
                    enabled: track.index > 0,
                    child: Text(l10n.moveUp),
                  ),
                  PopupMenuItem(
                    value: () => editor.moveTrack(track.index, track.index + 1),
                    enabled: track.index < last,
                    child: Text(l10n.moveDown),
                  ),
                  PopupMenuItem(
                    value: () => _remove(context),
                    enabled: guitars > 1,
                    child: Text(l10n.removeTrack),
                  ),
                ];
              },
            )
          // Keeps the columns lined up beside rows that have the menu.
          else if (!WorkspaceLayout.isCollapsed(context))
            const SizedBox(width: AccessibleSizes.minTouchTarget),
        ],
      ),
    );
  }
}

class _MixToggle extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  const _MixToggle({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox.square(
      dimension: AccessibleSizes.minTouchTarget,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: active ? AppColors.accent : null,
          foregroundColor: active ? Colors.white : null,
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    ),
  );
}

class _BarRowPainter extends CustomPainter {
  final List<bool> barsWithNotes;
  final Color color;

  const _BarRowPainter({required this.barsWithNotes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final (bar, filled) in barsWithNotes.indexed) {
      if (!filled) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          bar * kBarCellWidth + 1,
          Spacing.sm,
          kBarCellWidth - 2,
          size.height - 2 * Spacing.sm,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarRowPainter old) =>
      old.barsWithNotes != barsWithNotes || old.color != color;
}

class _SectionRow extends StatelessWidget {
  final List<BarInfo> bars;

  const _SectionRow({required this.bars});

  static String _time(int ms) =>
      '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: _sectionRowHeight,
      width: bars.length * kBarCellWidth,
      child: Stack(
        children: [
          for (final bar in bars)
            if (bar.section case final section?)
              Positioned(
                left: bar.index * kBarCellWidth,
                top: 0,
                child: Text(
                  '${section.marker.isEmpty ? section.text : section.marker} '
                  '${_time(bar.startMs)}',
                  style: style,
                ),
              ),
        ],
      ),
    );
  }
}
