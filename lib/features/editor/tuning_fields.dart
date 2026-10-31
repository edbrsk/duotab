import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'tuning_presets.dart';

const _flatNames = [
  'C',
  'D♭',
  'D',
  'E♭',
  'E',
  'F',
  'G♭',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
];

String _noteName(int midi) => '${_flatNames[midi % 12]}${midi ~/ 12 - 1}';

/// A dialog row: a label column and its control.
Widget labelledField(String label, Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: Spacing.md),
  child: Row(
    children: [
      SizedBox(width: 120, child: Text(label)),
      Expanded(child: child),
    ],
  ),
);

/// String count, tuning preset and, for a custom tuning, a note per string.
/// [onChanged] gets the open strings' MIDI notes, top string first.
class TuningFields extends StatefulWidget {
  final ValueChanged<List<int>> onChanged;

  /// Where the fields start, top string first; ignored when the dropdowns
  /// cannot show it, which then start at the first 6-string preset.
  final List<int>? initial;

  const TuningFields({required this.onChanged, this.initial, super.key});

  /// Whether the fields can show [tuning]: 6–8 strings, each within the
  /// octave either side of the preset that a custom string's dropdown spans.
  static bool fits(List<int> tuning) {
    if (!const [6, 7, 8].contains(tuning.length)) return false;
    final base = tuningPresets(tuning.length).first.tuning;
    return [
      for (final (i, note) in tuning.indexed) (note - base[i]).abs() <= 12,
    ].every((ok) => ok);
  }

  @override
  State<TuningFields> createState() => _TuningFieldsState();
}

class _TuningFieldsState extends State<TuningFields> {
  var _strings = 6;

  /// A preset's name, or null for a custom tuning.
  String? _preset = tuningPresets(6).first.name;
  var _tuning = [...tuningPresets(6).first.tuning];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null || !TuningFields.fits(initial)) return;
    _strings = initial.length;
    _tuning = [...initial];
    _preset = tuningPresets(_strings)
        .where((p) => listEquals(p.tuning, initial))
        .firstOrNull
        ?.name;
  }

  void _changed() => widget.onChanged([..._tuning]);

  void _setStrings(int strings) {
    setState(() {
      _strings = strings;
      _preset = tuningPresets(strings).first.name;
      _tuning = [...tuningPresets(strings).first.tuning];
    });
    _changed();
  }

  void _setPreset(String? name) {
    setState(() {
      _preset = name;
      if (name != null) {
        _tuning = [
          ...tuningPresets(_strings).firstWhere((t) => t.name == name).tuning,
        ];
      }
    });
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        labelledField(
          l10n.strings,
          SegmentedButton<int>(
            // Beside the outer screen's vertical bar a tick doesn't fit.
            showSelectedIcon: false,
            segments: [
              for (final n in const [6, 7, 8])
                ButtonSegment(value: n, label: Text('$n')),
            ],
            selected: {_strings},
            onSelectionChanged: (s) => _setStrings(s.single),
          ),
        ),
        labelledField(
          l10n.tuning,
          DropdownButton<String?>(
            key: const Key('tuning'),
            isExpanded: true,
            value: _preset,
            items: [
              for (final preset in tuningPresets(_strings))
                DropdownMenuItem(value: preset.name, child: Text(preset.name)),
              DropdownMenuItem(child: Text(l10n.custom)),
            ],
            onChanged: _setPreset,
          ),
        ),
        if (_preset == null)
          for (final (i, note) in _tuning.indexed)
            labelledField(
              l10n.stringN(i + 1),
              DropdownButton<int>(
                key: Key('string${i + 1}'),
                value: note,
                items: [
                  for (
                    var n = tuningPresets(_strings).first.tuning[i] - 12;
                    n <= tuningPresets(_strings).first.tuning[i] + 12;
                    n++
                  )
                    DropdownMenuItem(value: n, child: Text(_noteName(n))),
                ],
                onChanged: (n) {
                  setState(() => _tuning[i] = n!);
                  _changed();
                },
              ),
            ),
      ],
    );
  }
}
