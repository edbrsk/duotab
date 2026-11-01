import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../library/song_list_entry.dart';
import '../score/score_cubit.dart';
import 'chord_diagram.dart';
import 'editor_cubit.dart';

const _roots = [
  'C',
  'C♯',
  'D',
  'E♭',
  'E',
  'F',
  'F♯',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
];

/// Engine `ChordType`s and how the picker labels them.
const _types = {
  'maj': 'maj',
  'm': 'm',
  '7': '7',
  'maj7': 'maj7',
  'm7': 'm7',
  'm7b5': 'm7♭5',
  'dim7': 'dim7',
  'aug': 'aug',
  'sus2': 'sus2',
  'sus4': 'sus4',
  '6': '6',
  '5': '5',
};

const _additions = {
  'b9': '♭9',
  '9': '9',
  '#9': '♯9',
  '11': '11',
  '#11': '♯11',
  'b13': '♭13',
  '13': '13',
};

/// As the engine's: one of each group at a time.
const _clashes = [
  {'b9', '9', '#9'},
  {'11', '#11'},
  {'b13', '13'},
];

const _keyHeight = 34.0;

/// Builds a chord symbol by tapping and writes one of its positions on the
/// cursor's beat.
class ChordPicker extends StatefulWidget {
  const ChordPicker({super.key});

  @override
  State<ChordPicker> createState() => _ChordPickerState();
}

class _ChordPickerState extends State<ChordPicker> {
  int? _root;
  String? _type;
  var _added = <String>[];
  var _slash = false;
  int? _bass;

  /// Another file's chord name DuoScore can't build.
  String? _foreignName;
  ChordPositions? _positions;

  /// What [_positions] were found for: tiles for another chord or tuning would
  /// be refused when tapped.
  ChordSpec? _positionsFor;

  /// Only the newest request's reply is shown.
  var _request = 0;

  ChordSpec? get _spec => _root == null || _type == null
      ? null
      : ChordSpec(
          root: _root!,
          type: _type!,
          additions: _added,
          bass: _slash ? _bass : null,
        );

  @override
  void initState() {
    super.initState();
    _follow(context.read<EditorCubit>().state);
  }

  /// A beat with a chord shows it; a beat without one keeps the chord being
  /// built, ready to write again.
  void _follow(EditorState state) {
    if (state.chordSpec case final spec?) {
      _root = spec.root;
      _type = spec.type;
      _added = [...spec.additions];
      _slash = spec.bass != null;
      _bass = spec.bass;
      _foreignName = null;
      _refresh();
    } else if (state.chordName case final name?) {
      _root = null;
      _type = null;
      _added = [];
      _slash = false;
      _bass = null;
      _foreignName = name;
      _positions = null;
      _request++;
    }
  }

  Future<void> _refresh() async {
    final spec = _spec;
    final request = ++_request;
    if (spec == null) {
      setState(() => _positions = null);
      return;
    }
    setState(() => _positionsFor = null);
    final positions = await context.read<EditorCubit>().chordPositions(spec);
    if (!mounted || request != _request) return;
    setState(() {
      _positions = positions;
      _positionsFor = spec;
    });
  }

  void _change(VoidCallback change) {
    setState(() {
      change();
      _foreignName = null;
    });
    _refresh();
  }

  void _toggleAddition(String addition) => _change(() {
    if (_added.contains(addition)) {
      _added = [..._added]..remove(addition);
    } else {
      final group = _clashes.firstWhere((g) => g.contains(addition));
      _added = [..._added.where((a) => !group.contains(a)), addition];
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final editor = context.watch<EditorCubit>().state;
    final enabled = editor.position != null;
    final track = context.select<ScoreCubit, TrackSummary?>(
      (c) => c.state.song?.tracks
          .where((t) => t.index == editor.position?.track)
          .firstOrNull,
    );
    final spec = _spec;
    final positions = spec != null && _positionsFor == spec ? _positions : null;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
      child: Text(text.toUpperCase(), style: textTheme.labelSmall),
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<EditorCubit, EditorState>(
          listenWhen: (before, after) =>
              before.position != after.position ||
              before.chordSpec != after.chordSpec ||
              before.chordName != after.chordName,
          listener: (_, state) => setState(() => _follow(state)),
        ),
        // Another track or a retune: the same chord sits elsewhere on the neck.
        BlocListener<ScoreCubit, ScoreState>(
          listenWhen: (before, after) =>
              before.selectedTrackIndex != after.selectedTrackIndex ||
              !listEquals(_tuningOf(before), _tuningOf(after)),
          listener: (_, _) {
            if (_spec != null) _refresh();
          },
        ),
      ],
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading(l10n.chordRoot),
              _Keys(
                labels: _roots,
                selected: (i) => _root == i,
                onTap: (i) => _change(() => _root = i),
              ),
              heading(l10n.chordType),
              _Keys(
                labels: _types.values.toList(),
                selected: (i) => _type == _types.keys.elementAt(i),
                onTap: (i) => _change(() => _type = _types.keys.elementAt(i)),
              ),
              heading(l10n.chordAddOrAlter),
              _Keys(
                labels: [..._additions.values, '/bass'],
                selected: (i) => i == _additions.length
                    ? _slash
                    : _added.contains(_additions.keys.elementAt(i)),
                onTap: (i) => i == _additions.length
                    ? _change(() {
                        _slash = !_slash;
                        if (!_slash) _bass = null;
                      })
                    : _toggleAddition(_additions.keys.elementAt(i)),
              ),
              if (_slash) ...[
                heading(l10n.chordBass),
                _Keys(
                  labels: _roots,
                  selected: (i) => _bass == i,
                  onTap: (i) => _change(() => _bass = i),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: Spacing.md),
                child: Column(
                  children: [
                    Text(
                      _foreignName ?? positions?.name ?? ' ',
                      style: textTheme.titleLarge?.copyWith(
                        fontFamily: 'Georgia',
                      ),
                    ),
                    if (track?.tuning case final tuning?)
                      Text(
                        '${tuningLabel(tuning)} · ${l10n.stringsCount(tuning.length)}',
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (spec != null && positions != null) ...[
                heading(l10n.chordPositionsHeading),
                if (positions.positions.isEmpty)
                  Text(l10n.noChordPosition, style: textTheme.bodySmall)
                else
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: positions.positions.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: Spacing.xs),
                      itemBuilder: (context, i) {
                        final position = positions.positions[i];
                        final chosen =
                            editor.chordSpec == spec &&
                            listEquals(editor.beatFrets, position.frets);
                        return _PositionTile(
                          key: chosen ? const Key('position-selected') : null,
                          position: position,
                          chosen: chosen,
                          label: position.open
                              ? l10n.positionOpen
                              : l10n.positionFret(position.lowestFret),
                          onTap: () => context.read<EditorCubit>().command(
                            SetChord(spec, position.frets),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Four keys to a row.
List<int>? _tuningOf(ScoreState state) => state.song?.tracks
    .where((t) => t.index == state.selectedTrackIndex)
    .firstOrNull
    ?.tuning;

class _Keys extends StatelessWidget {
  final List<String> labels;
  final bool Function(int index) selected;
  final void Function(int index) onTap;

  const _Keys({
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (var i = 0; i < labels.length; i += 4)
        [for (var j = i; j < i + 4 && j < labels.length; j++) j],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                for (var k = 0; k < 4; k++) ...[
                  if (k > 0) const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: k < row.length
                        ? _Key(
                            label: labels[row[k]],
                            selected: selected(row[k]),
                            onTap: () => onTap(row[k]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Key({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    key: selected ? const Key('chord-key-selected') : null,
    color: selected ? AppColors.accent : AppColors.key,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: SizedBox(
        height: _keyHeight,
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ),
    ),
  );
}

class _PositionTile extends StatelessWidget {
  final ChordPosition position;
  final bool chosen;
  final String label;
  final VoidCallback onTap;

  const _PositionTile({
    required this.position,
    required this.chosen,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.key,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: chosen
          ? const BorderSide(color: AppColors.accent, width: 2)
          : BorderSide.none,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xs),
        child: Column(
          children: [
            ChordDiagram(
              frets: position.frets,
              firstFret: position.open ? 1 : position.lowestFret,
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    ),
  );
}
