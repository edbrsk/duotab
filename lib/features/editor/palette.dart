import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import 'editor_cubit.dart';
import 'smufl.dart';

/// Guitar Pro's left-hand palette, drawn with Bravura's notation symbols.
class Palette extends StatelessWidget {
  const Palette({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final noteNames = {
      1: l10n.wholeNote,
      2: l10n.halfNote,
      4: l10n.quarterNote,
      8: l10n.eighthNote,
      16: l10n.sixteenthNote,
      32: l10n.thirtySecondNote,
      64: l10n.sixtyFourthNote,
    };
    final restNames = {
      1: l10n.wholeRest,
      2: l10n.halfRest,
      4: l10n.quarterRest,
      8: l10n.eighthRest,
      16: l10n.sixteenthRest,
      32: l10n.thirtySecondRest,
      64: l10n.sixtyFourthRest,
    };
    final voice = state.position?.voice ?? 0;
    // Voices and rests change the song, so they wait for a placed cursor.
    final placed = state.position != null;

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.undo,
                icon: const Icon(Icons.undo),
                onPressed: state.canUndo ? editor.undo : null,
              ),
              IconButton(
                tooltip: l10n.redo,
                icon: const Icon(Icons.redo),
                onPressed: state.canRedo ? editor.redo : null,
              ),
            ],
          ),
          _Group(
            title: l10n.voice,
            children: [
              for (var v = 0; v < 4; v++)
                _Chip(
                  tooltip: l10n.voiceN(v + 1),
                  label: Text('${v + 1}'),
                  selected: v == voice,
                  onSelected: placed
                      ? () => editor.command(SelectVoice(v))
                      : null,
                ),
            ],
          ),
          _Group(
            title: l10n.noteValue,
            children: [
              for (final MapEntry(key: duration, value: glyph)
                  in Smufl.notes.entries)
                _Chip(
                  tooltip: noteNames[duration]!,
                  label: _Glyph(glyph),
                  selected: state.duration == duration,
                  onSelected: () => editor.chooseDuration(duration),
                ),
            ],
          ),
          _Group(
            title: l10n.rests,
            children: [
              for (final MapEntry(key: duration, value: glyph)
                  in Smufl.rests.entries)
                _Chip(
                  tooltip: restNames[duration]!,
                  label: _Glyph(glyph),
                  selected: false,
                  onSelected: placed
                      ? () async {
                          await editor.chooseDuration(duration);
                          await editor.command(const SetRest());
                        }
                      : null,
                ),
            ],
          ),
          _Group(
            title: l10n.dots,
            children: [
              _Chip(
                tooltip: l10n.dot,
                label: const _Glyph(Smufl.augmentationDot),
                selected: state.dots == 1,
                onSelected: () => editor.chooseDots(state.dots == 1 ? 0 : 1),
              ),
              _Chip(
                tooltip: l10n.doubleDot,
                label: const _Glyph(
                  '${Smufl.augmentationDot}${Smufl.augmentationDot}',
                ),
                selected: state.dots == 2,
                onSelected: () => editor.chooseDots(state.dots == 2 ? 0 : 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(spacing: Spacing.xs, runSpacing: Spacing.xs, children: children),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String tooltip;
  final Widget label;
  final bool selected;
  final VoidCallback? onSelected;

  const _Chip({
    required this.tooltip,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: ChoiceChip(
      label: label,
      selected: selected,
      showCheckmark: false,
      backgroundColor: AppColors.key,
      selectedColor: AppColors.accent,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
    ),
  );
}

class _Glyph extends StatelessWidget {
  final String glyph;

  const _Glyph(this.glyph);

  @override
  Widget build(BuildContext context) => Text(
    glyph,
    style: const TextStyle(fontFamily: 'Bravura', fontSize: 22, height: 1),
  );
}
