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
    final dynamicNames = {
      'ppp': l10n.pianississimo,
      'pp': l10n.pianissimo,
      'p': l10n.piano,
      'mp': l10n.mezzoPiano,
      'mf': l10n.mezzoForte,
      'f': l10n.forte,
      'ff': l10n.fortissimo,
      'fff': l10n.fortississimo,
    };
    final tupletNames = {
      3: l10n.triplet,
      5: l10n.quintuplet,
      6: l10n.sextuplet,
    };
    // Voices, rests and techniques change the song, so they wait for a placed
    // cursor; note techniques also need a note on the cursor string.
    final placed = state.position != null;
    final onNote = placed && state.hasNote;

    _Chip technique(
      String id,
      String tooltip,
      Widget label, {
      bool needsNote = true,
    }) => _Chip(
      tooltip: tooltip,
      label: label,
      selected: state.techniques.contains(id),
      onSelected: (needsNote ? onNote : placed)
          ? () => editor.toggle(id)
          : null,
    );

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
              for (final MapEntry(key: tuplet, value: glyph)
                  in Smufl.tuplets.entries)
                _Chip(
                  tooltip: tupletNames[tuplet]!,
                  label: _Glyph(glyph),
                  selected: state.tuplet == tuplet,
                  onSelected: placed
                      ? () => editor.setTuplet(
                          state.tuplet == tuplet ? 1 : tuplet,
                        )
                      : null,
                ),
              technique('tie', l10n.tie, const _Text('‿')),
              _Chip(
                tooltip: l10n.graceNote,
                label: const _Glyph(Smufl.graceNote),
                selected: false,
                onSelected: placed ? editor.addGrace : null,
              ),
            ],
          ),
          _Group(
            title: l10n.accidentals,
            children: [
              technique(
                'doubleFlat',
                l10n.doubleFlat,
                const _Glyph(Smufl.doubleFlat),
              ),
              technique('flat', l10n.flat, const _Glyph(Smufl.flat)),
              technique('natural', l10n.natural, const _Glyph(Smufl.natural)),
              technique('sharp', l10n.sharp, const _Glyph(Smufl.sharp)),
              technique(
                'doubleSharp',
                l10n.doubleSharp,
                const _Glyph(Smufl.doubleSharp),
              ),
            ],
          ),
          _Group(
            title: l10n.dynamics,
            children: [
              for (final MapEntry(key: mark, value: glyph)
                  in Smufl.dynamics.entries)
                _Chip(
                  tooltip: dynamicNames[mark]!,
                  label: _Glyph(glyph),
                  selected: state.dynamicMark == mark,
                  onSelected: placed ? () => editor.setDynamic(mark) : null,
                ),
              technique(
                'crescendo',
                l10n.crescendo,
                const _Text('cresc.'),
                needsNote: false,
              ),
              technique(
                'diminuendo',
                l10n.diminuendo,
                const _Text('dim.'),
                needsNote: false,
              ),
            ],
          ),
          _Group(
            title: l10n.guitarTechniques,
            children: [
              technique('hammerPull', l10n.hammerPull, const _Text('H/P')),
              technique('slide', l10n.slide, const _Text('sl.')),
              technique('bend', l10n.bend, const _Text('⤴')),
              technique('vibrato', l10n.vibrato, const _Glyph(Smufl.vibrato)),
              technique('palmMute', l10n.palmMute, const _Text('P.M.')),
              technique('letRing', l10n.letRing, const _Text('let ring')),
              technique(
                'deadNote',
                l10n.deadNote,
                const _Glyph(Smufl.deadNote),
              ),
              technique('ghostNote', l10n.ghostNote, const _Text('( )')),
              technique(
                'naturalHarmonic',
                l10n.naturalHarmonic,
                const _Text('N.H.'),
              ),
              technique(
                'artificialHarmonic',
                l10n.artificialHarmonic,
                const _Text('A.H.'),
              ),
              technique(
                'tapping',
                l10n.tapping,
                const _Text('T'),
                needsNote: false,
              ),
              technique(
                'pickUp',
                l10n.pickUp,
                const _Glyph(Smufl.pickUp),
                needsNote: false,
              ),
              technique(
                'pickDown',
                l10n.pickDown,
                const _Glyph(Smufl.pickDown),
                needsNote: false,
              ),
              technique(
                'tremolo',
                l10n.tremoloPicking,
                const _Glyph(Smufl.tremolo),
                needsNote: false,
              ),
            ],
          ),
          _Group(
            title: l10n.articulation,
            children: [
              technique('accent', l10n.accent, const _Glyph(Smufl.accent)),
              technique('marcato', l10n.marcato, const _Glyph(Smufl.marcato)),
              technique(
                'staccato',
                l10n.staccato,
                const _Glyph(Smufl.staccato),
              ),
              technique('tenuto', l10n.tenuto, const _Glyph(Smufl.tenuto)),
              technique(
                'fermata',
                l10n.fermata,
                const _Glyph(Smufl.fermata),
                needsNote: false,
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

/// Guitar Pro's printed abbreviation, for a technique without a SMuFL symbol.
class _Text extends StatelessWidget {
  final String text;

  const _Text(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 14, height: 1));
}
