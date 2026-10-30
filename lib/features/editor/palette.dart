import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import 'bar_menus.dart';
import 'editor_cubit.dart';
import 'palette_chips.dart';
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

    PaletteChip technique(
      String id,
      String tooltip,
      Widget label, {
      bool needsNote = true,
    }) => PaletteChip(
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
          PaletteGroup(
            title: l10n.voice,
            children: [
              for (var v = 0; v < 4; v++)
                PaletteChip(
                  tooltip: l10n.voiceN(v + 1),
                  label: Text('${v + 1}'),
                  selected: v == voice,
                  onSelected: placed
                      ? () => editor.command(SelectVoice(v))
                      : null,
                ),
            ],
          ),
          PaletteGroup(
            title: l10n.noteValue,
            children: [
              for (final MapEntry(key: duration, value: glyph)
                  in Smufl.notes.entries)
                PaletteChip(
                  tooltip: noteNames[duration]!,
                  label: PaletteGlyph(glyph),
                  selected: state.duration == duration,
                  onSelected: () => editor.chooseDuration(duration),
                ),
            ],
          ),
          PaletteGroup(
            title: l10n.rests,
            children: [
              for (final MapEntry(key: duration, value: glyph)
                  in Smufl.rests.entries)
                PaletteChip(
                  tooltip: restNames[duration]!,
                  label: PaletteGlyph(glyph),
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
          PaletteGroup(
            title: l10n.dots,
            children: [
              PaletteChip(
                tooltip: l10n.dot,
                label: const PaletteGlyph(Smufl.augmentationDot),
                selected: state.dots == 1,
                onSelected: () => editor.chooseDots(state.dots == 1 ? 0 : 1),
              ),
              PaletteChip(
                tooltip: l10n.doubleDot,
                label: const PaletteGlyph(
                  '${Smufl.augmentationDot}${Smufl.augmentationDot}',
                ),
                selected: state.dots == 2,
                onSelected: () => editor.chooseDots(state.dots == 2 ? 0 : 2),
              ),
              for (final MapEntry(key: tuplet, value: glyph)
                  in Smufl.tuplets.entries)
                PaletteChip(
                  tooltip: tupletNames[tuplet]!,
                  label: PaletteGlyph(glyph),
                  selected: state.tuplet == tuplet,
                  onSelected: placed
                      ? () => editor.setTuplet(
                          state.tuplet == tuplet ? 1 : tuplet,
                        )
                      : null,
                ),
              technique('tie', l10n.tie, const PaletteText('‿')),
              PaletteChip(
                tooltip: l10n.graceNote,
                label: const PaletteGlyph(Smufl.graceNote),
                selected: false,
                onSelected: placed ? editor.addGrace : null,
              ),
            ],
          ),
          PaletteGroup(
            title: l10n.bar,
            children: const [
              ClefChip(),
              TimeSignatureChip(),
              KeySignatureChip(),
              TempoChip(),
              RepeatStartChip(),
              RepeatEndChip(),
              EndingsChip(),
              DirectionsChip(),
            ],
          ),
          PaletteGroup(
            title: l10n.bars,
            children: [
              PaletteChip(
                tooltip: l10n.insertBar,
                label: const Icon(Icons.add_box_outlined),
                selected: false,
                onSelected: placed ? editor.insertBar : null,
              ),
              PaletteChip(
                tooltip: l10n.deleteBar,
                label: const Icon(Icons.delete_outline),
                selected: false,
                onSelected: placed ? editor.deleteBar : null,
              ),
              PaletteChip(
                tooltip: l10n.copyBars,
                label: const Icon(Icons.content_copy),
                selected: false,
                onSelected: placed ? editor.copyBars : null,
              ),
              PaletteChip(
                tooltip: l10n.pasteBars,
                label: const Icon(Icons.content_paste),
                selected: false,
                onSelected: placed && state.canPaste ? editor.pasteBars : null,
              ),
            ],
          ),
          PaletteGroup(
            title: l10n.accidentals,
            children: [
              technique(
                'doubleFlat',
                l10n.doubleFlat,
                const PaletteGlyph(Smufl.doubleFlat),
              ),
              technique('flat', l10n.flat, const PaletteGlyph(Smufl.flat)),
              technique(
                'natural',
                l10n.natural,
                const PaletteGlyph(Smufl.natural),
              ),
              technique('sharp', l10n.sharp, const PaletteGlyph(Smufl.sharp)),
              technique(
                'doubleSharp',
                l10n.doubleSharp,
                const PaletteGlyph(Smufl.doubleSharp),
              ),
            ],
          ),
          PaletteGroup(
            title: l10n.dynamics,
            children: [
              for (final MapEntry(key: mark, value: glyph)
                  in Smufl.dynamics.entries)
                PaletteChip(
                  tooltip: dynamicNames[mark]!,
                  label: PaletteGlyph(glyph),
                  selected: state.dynamicMark == mark,
                  onSelected: placed ? () => editor.setDynamic(mark) : null,
                ),
              technique(
                'crescendo',
                l10n.crescendo,
                const PaletteText('cresc.'),
                needsNote: false,
              ),
              technique(
                'diminuendo',
                l10n.diminuendo,
                const PaletteText('dim.'),
                needsNote: false,
              ),
            ],
          ),
          PaletteGroup(
            title: l10n.guitarTechniques,
            children: [
              technique(
                'hammerPull',
                l10n.hammerPull,
                const PaletteText('H/P'),
              ),
              technique('slide', l10n.slide, const PaletteText('sl.')),
              _BendChip(onNote: onNote),
              technique(
                'vibrato',
                l10n.vibrato,
                const PaletteGlyph(Smufl.vibrato),
              ),
              technique('palmMute', l10n.palmMute, const PaletteText('P.M.')),
              technique('letRing', l10n.letRing, const PaletteText('let ring')),
              technique(
                'deadNote',
                l10n.deadNote,
                const PaletteGlyph(Smufl.deadNote),
              ),
              technique('ghostNote', l10n.ghostNote, const PaletteText('( )')),
              technique(
                'naturalHarmonic',
                l10n.naturalHarmonic,
                const PaletteText('N.H.'),
              ),
              technique(
                'artificialHarmonic',
                l10n.artificialHarmonic,
                const PaletteText('A.H.'),
              ),
              technique(
                'tapping',
                l10n.tapping,
                const PaletteText('T'),
                needsNote: false,
              ),
              technique(
                'pickUp',
                l10n.pickUp,
                const PaletteGlyph(Smufl.pickUp),
                needsNote: false,
              ),
              technique(
                'pickDown',
                l10n.pickDown,
                const PaletteGlyph(Smufl.pickDown),
                needsNote: false,
              ),
              technique(
                'tremolo',
                l10n.tremoloPicking,
                const PaletteGlyph(Smufl.tremolo),
                needsNote: false,
              ),
            ],
          ),
          PaletteGroup(
            title: l10n.articulation,
            children: [
              technique(
                'accent',
                l10n.accent,
                const PaletteGlyph(Smufl.accent),
              ),
              technique(
                'marcato',
                l10n.marcato,
                const PaletteGlyph(Smufl.marcato),
              ),
              technique(
                'staccato',
                l10n.staccato,
                const PaletteGlyph(Smufl.staccato),
              ),
              technique(
                'tenuto',
                l10n.tenuto,
                const PaletteGlyph(Smufl.tenuto),
              ),
              technique(
                'fermata',
                l10n.fermata,
                const PaletteGlyph(Smufl.fermata),
                needsNote: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens a menu of bend types and amounts, as Guitar Pro's bend dialog.
class _BendChip extends StatelessWidget {
  final bool onNote;

  const _BendChip({required this.onNote});

  static const _amounts = [
    '¼',
    '½',
    '¾',
    'full',
    '1¼',
    '1½',
    '1¾',
    '2',
    '2¼',
    '2½',
    '2¾',
    '3',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final kinds = {
      'bend': l10n.bend,
      'bendRelease': l10n.bendRelease,
      'prebend': l10n.prebend,
      'prebendRelease': l10n.prebendRelease,
    };
    String amountName(int amount, String label) => switch (amount) {
      < 4 => l10n.bendTone(label),
      4 => l10n.fullBend,
      _ => l10n.bendTones(label),
    };
    final heading = Theme.of(context).textTheme.labelSmall;

    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: SizedBox(
            width: _bendMenuWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.bendKind.toUpperCase(), style: heading),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: [
                    for (final MapEntry(key: kind, value: name)
                        in kinds.entries)
                      PaletteChip(
                        tooltip: name,
                        label: PaletteText(name),
                        selected: state.bendKind == kind,
                        onSelected: () =>
                            editor.setBend(kind, state.bendAmount),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text(l10n.bendAmount.toUpperCase(), style: heading),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: [
                    for (final (i, label) in _amounts.indexed)
                      PaletteChip(
                        tooltip: amountName(i + 1, label),
                        label: PaletteText(label),
                        selected:
                            state.bendKind != null && state.bendAmount == i + 1,
                        onSelected: () =>
                            editor.setBend(state.bendKind ?? 'bend', i + 1),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed:
                      state.bendKind == null &&
                          !state.techniques.contains('bend')
                      ? null
                      : () => editor.setBend(null, state.bendAmount),
                  child: Text(l10n.removeBend),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => PaletteChip(
        tooltip: l10n.bend,
        label: const PaletteText('⤴'),
        selected: state.techniques.contains('bend'),
        onSelected: onNote ? controller.open : null,
      ),
    );
  }
}

const _bendMenuWidth = 280.0;
