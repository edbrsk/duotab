import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../playback/playback_cubit.dart';
import '../playback/practice_settings.dart';
import 'score_cubit.dart';

const kTrackRowHeight = 48.0;
const kBarCellWidth = 14.0;
const kTrackColumnWidth = 184.0;
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
  int? _revealedBar;

  @override
  void dispose() {
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
    final rows = _expanded
        ? song.tracks
        : [
            song.tracks.firstWhere(
              (t) => t.index == drawn,
              orElse: () => song.tracks.first,
            ),
          ];
    final barCount = song.bars.length;
    final maxBody =
        MediaQuery.sizeOf(context).height * kDrawerMaxHeightFraction -
        _headerHeight;
    final bodyHeight = min(
      rows.length * kTrackRowHeight + _sectionRowHeight,
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
            SizedBox(
              height: bodyHeight,
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: kTrackColumnWidth,
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
                            ),
                        ],
                      ),
                    ),
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
                                      key: ValueKey('barRow-${track.index}'),
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
                                          barsWithNotes: track.barsWithNotes,
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

  const _TrackRow({
    required this.track,
    required this.drawn,
    required this.practice,
    super.key,
  });

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
            label: 'M',
            tooltip: l10n.muteTrack(track.name),
            active: practice.mute,
            onPressed: () => playback.setMute(track.index, on: !practice.mute),
          ),
          _MixToggle(
            label: 'S',
            tooltip: l10n.soloTrack(track.name),
            active: practice.solo,
            onPressed: () => playback.setSolo(track.index, on: !practice.solo),
          ),
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
