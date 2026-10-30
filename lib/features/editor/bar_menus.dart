import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'editor_cubit.dart';
import 'palette_chips.dart';
import 'smufl.dart';

const _menuWidth = 280.0;

/// Flats to sharps: index 0 is seven flats, index 14 seven sharps.
const _majorKeys = [
  'C♭', 'G♭', 'D♭', 'A♭', 'E♭', 'B♭', 'F', 'C', //
  'G', 'D', 'A', 'E', 'B', 'F♯', 'C♯',
];
const _minorKeys = [
  'A♭m', 'E♭m', 'B♭m', 'Fm', 'Cm', 'Gm', 'Dm', 'Am', //
  'Em', 'Bm', 'F♯m', 'C♯m', 'G♯m', 'D♯m', 'A♯m',
];

String keyName(int key, {required bool minor}) =>
    (minor ? _minorKeys : _majorKeys)[key + 7];

class _MenuChip extends StatelessWidget {
  final String tooltip;
  final Widget label;
  final bool enabled;
  final List<Widget> Function(BuildContext context) menu;

  const _MenuChip({
    required this.tooltip,
    required this.label,
    required this.enabled,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: SizedBox(
          width: _menuWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: menu(context),
          ),
        ),
      ),
    ],
    builder: (context, controller, _) => PaletteChip(
      tooltip: tooltip,
      label: label,
      selected: false,
      onSelected: enabled ? controller.open : null,
    ),
  );
}

Widget _heading(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: Spacing.xs),
  child: Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall,
  ),
);

Widget _wrap(List<Widget> children) =>
    Wrap(spacing: Spacing.xs, runSpacing: Spacing.xs, children: children);

class ClefChip extends StatelessWidget {
  const ClefChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final clefs = {
      'treble': (l10n.trebleClef, Smufl.gClef),
      'bass': (l10n.bassClef, Smufl.fClef),
    };
    return _MenuChip(
      tooltip: l10n.clef,
      label: PaletteGlyph(state.barClef == 'bass' ? Smufl.fClef : Smufl.gClef),
      enabled: state.position != null,
      menu: (_) => [
        _wrap([
          for (final MapEntry(key: clef, value: (name, glyph)) in clefs.entries)
            PaletteChip(
              tooltip: name,
              label: PaletteGlyph(glyph),
              selected: state.barClef == clef,
              onSelected: () => editor.setClef(clef),
            ),
        ]),
      ],
    );
  }
}

class TimeSignatureChip extends StatelessWidget {
  const TimeSignatureChip({super.key});

  static const _presets = [
    (2, 4),
    (3, 4),
    (4, 4),
    (5, 4),
    (6, 8),
    (7, 8),
    (9, 8),
    (12, 8),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final numerator = state.barNumerator;
    final denominator = state.barDenominator;
    return _MenuChip(
      tooltip: l10n.timeSignature,
      label: PaletteText('$numerator/$denominator'),
      enabled: state.position != null,
      menu: (context) => [
        _wrap([
          for (final (n, d) in _presets)
            PaletteChip(
              tooltip: '$n/$d',
              label: PaletteText('$n/$d'),
              selected: n == numerator && d == denominator,
              onSelected: () => editor.setTimeSignature(n, d),
            ),
        ]),
        const SizedBox(height: Spacing.sm),
        _heading(context, l10n.custom),
        Row(
          children: [
            IconButton(
              tooltip: l10n.fewerBeats,
              icon: const Icon(Icons.remove),
              onPressed: numerator > 1
                  ? () => editor.setTimeSignature(numerator - 1, denominator)
                  : null,
            ),
            Text('$numerator', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              tooltip: l10n.moreBeats,
              icon: const Icon(Icons.add),
              onPressed: numerator < 32
                  ? () => editor.setTimeSignature(numerator + 1, denominator)
                  : null,
            ),
          ],
        ),
        _wrap([
          for (final d in [2, 4, 8, 16])
            PaletteChip(
              tooltip: l10n.beatValue(d),
              label: PaletteText('$d'),
              selected: d == denominator,
              onSelected: () => editor.setTimeSignature(numerator, d),
            ),
        ]),
      ],
    );
  }
}

class KeySignatureChip extends StatelessWidget {
  const KeySignatureChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<EditorCubit>().state;
    return _MenuChip(
      tooltip: l10n.keySignature,
      label: PaletteText(keyName(state.barKey, minor: state.barMinor)),
      enabled: state.position != null,
      menu: (_) => [const _KeyMenu()],
    );
  }
}

class _KeyMenu extends StatefulWidget {
  const _KeyMenu();

  @override
  State<_KeyMenu> createState() => _KeyMenuState();
}

class _KeyMenuState extends State<_KeyMenu> {
  late var _minor = context.read<EditorCubit>().state.barMinor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.major)),
            ButtonSegment(value: true, label: Text(l10n.minor)),
          ],
          selected: {_minor},
          onSelectionChanged: (choice) =>
              setState(() => _minor = choice.single),
        ),
        const SizedBox(height: Spacing.sm),
        _wrap([
          for (var key = -7; key <= 7; key++)
            PaletteChip(
              tooltip: keyName(key, minor: _minor),
              label: PaletteText(keyName(key, minor: _minor)),
              selected: state.barKey == key && state.barMinor == _minor,
              onSelected: () => editor.setKeySignature(key, minor: _minor),
            ),
        ]),
      ],
    );
  }
}

class TempoChip extends StatelessWidget {
  const TempoChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final position = state.position;
    return PaletteChip(
      tooltip: l10n.tempoChange,
      label: PaletteText(l10n.tempoMarking(state.barTempo)),
      selected: false,
      onSelected: position == null
          ? null
          : () async {
              final choice = await showDialog<({int? bpm})>(
                context: context,
                builder: (_) => _TempoDialog(
                  tempo: state.barTempo,
                  canRemove: position.bar > 0 && state.barTempoChange,
                ),
              );
              if (choice != null) await editor.setTempo(choice.bpm);
            },
    );
  }
}

/// Pops with the new tempo, `bpm: null` to remove the marking, or nothing
/// when cancelled.
class _TempoDialog extends StatefulWidget {
  final int tempo;
  final bool canRemove;

  const _TempoDialog({required this.tempo, required this.canRemove});

  @override
  State<_TempoDialog> createState() => _TempoDialogState();
}

class _TempoDialogState extends State<_TempoDialog> {
  late final _controller = TextEditingController(text: '${widget.tempo}');

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The range New song allows.
  int? get _bpm => switch (int.tryParse(_controller.text)) {
    final bpm? when bpm >= 30 && bpm <= 300 => bpm,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bpm = _bpm;
    return AlertDialog(
      title: Text(l10n.tempoChange),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: l10n.tempoBpm),
      ),
      actions: [
        TextButton(
          onPressed: widget.canRemove
              ? () => Navigator.pop(context, (bpm: null))
              : null,
          child: Text(l10n.removeTempoChange),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: bpm == null
              ? null
              : () => Navigator.pop(context, (bpm: bpm)),
          child: Text(l10n.setTempo),
        ),
      ],
    );
  }
}

class RepeatStartChip extends StatelessWidget {
  const RepeatStartChip({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    return PaletteChip(
      tooltip: AppLocalizations.of(context)!.repeatStart,
      label: const PaletteGlyph(Smufl.repeatLeft),
      selected: state.repeatStart,
      onSelected: state.position != null ? editor.toggleRepeatStart : null,
    );
  }
}

class RepeatEndChip extends StatelessWidget {
  const RepeatEndChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    return _MenuChip(
      tooltip: l10n.repeatEnd,
      label: const PaletteGlyph(Smufl.repeatRight),
      enabled: state.position != null,
      menu: (_) => [
        _wrap([
          for (var count = 2; count <= 8; count++)
            PaletteChip(
              tooltip: l10n.playTimes(count),
              label: PaletteText('×$count'),
              selected: state.repeatCount == count,
              onSelected: () => editor.setRepeatEnd(count),
            ),
        ]),
        const SizedBox(height: Spacing.sm),
        TextButton(
          onPressed: state.repeatCount == 0
              ? null
              : () => editor.setRepeatEnd(0),
          child: Text(l10n.noRepeat),
        ),
      ],
    );
  }
}

class EndingsChip extends StatelessWidget {
  const EndingsChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final endings = state.endings;
    return _MenuChip(
      tooltip: l10n.alternateEnding,
      label: PaletteText(
        endings.isEmpty ? '1.' : endings.map((e) => '$e.').join(),
      ),
      enabled: state.position != null,
      menu: (_) => [
        _wrap([
          for (var ending = 1; ending <= 8; ending++)
            PaletteChip(
              tooltip: l10n.endingN(ending),
              label: PaletteText('$ending.'),
              selected: endings.contains(ending),
              onSelected: () => editor.setEndings(
                endings.contains(ending)
                    ? [...endings.where((e) => e != ending)]
                    : ([...endings, ending]..sort()),
              ),
            ),
        ]),
      ],
    );
  }
}

class DirectionsChip extends StatelessWidget {
  const DirectionsChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final state = context.watch<EditorCubit>().state;
    final targets = [
      ('segno', l10n.segno, const PaletteGlyph(Smufl.segno)),
      ('coda', l10n.coda, const PaletteGlyph(Smufl.coda)),
      ('fine', l10n.fine, const PaletteText('Fine')),
    ];
    final jumps = [
      ('daCapo', l10n.daCapo, 'D.C.'),
      ('daCapoAlFine', l10n.daCapoAlFine, 'D.C. al Fine'),
      ('daCapoAlCoda', l10n.daCapoAlCoda, 'D.C. al Coda'),
      ('dalSegno', l10n.dalSegno, 'D.S.'),
      ('dalSegnoAlFine', l10n.dalSegnoAlFine, 'D.S. al Fine'),
      ('dalSegnoAlCoda', l10n.dalSegnoAlCoda, 'D.S. al Coda'),
      ('toCoda', l10n.toCoda, 'To Coda'),
    ];
    PaletteChip direction(String id, String name, Widget label) => PaletteChip(
      tooltip: name,
      label: label,
      selected: state.directions.contains(id),
      onSelected: () => editor.toggleDirection(id),
    );
    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: SizedBox(
            width: _menuWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context, l10n.targets),
                _wrap([
                  for (final (id, name, label) in targets)
                    direction(id, name, label),
                ]),
                const SizedBox(height: Spacing.sm),
                _heading(context, l10n.jumps),
                _wrap([
                  for (final (id, name, label) in jumps)
                    direction(id, name, PaletteText(label)),
                ]),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => PaletteChip(
        tooltip: l10n.directions,
        label: const PaletteGlyph(Smufl.segno),
        selected: state.directions.isNotEmpty,
        onSelected: state.position != null ? controller.open : null,
      ),
    );
  }
}
