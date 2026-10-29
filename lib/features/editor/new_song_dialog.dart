import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import 'tuning_presets.dart';

const _timeSignatures = [(4, 4), (3, 4), (6, 8), (7, 8), (5, 4), (12, 8)];
const _denominators = [1, 2, 4, 8, 16, 32];
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

/// Pops the [NewSongOptions] chosen, or null when cancelled.
class NewSongDialog extends StatefulWidget {
  const NewSongDialog({super.key});

  @override
  State<NewSongDialog> createState() => _NewSongDialogState();
}

class _NewSongDialogState extends State<NewSongDialog> {
  final _title = TextEditingController();
  final _tempo = TextEditingController(text: '120');
  var _strings = 6;

  /// A preset's name, or null for a custom tuning.
  String? _preset = tuningPresets(6).first.name;
  var _tuning = [...tuningPresets(6).first.tuning];
  (int, int)? _timeSignature = _timeSignatures.first;
  var _numerator = 4;
  var _denominator = 4;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _tempo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _tempo.dispose();
    super.dispose();
  }

  int? get _tempoValue => switch (int.tryParse(_tempo.text)) {
    final t? when t >= 30 && t <= 300 => t,
    _ => null,
  };

  void _setStrings(int strings) => setState(() {
    _strings = strings;
    _preset = tuningPresets(strings).first.name;
    _tuning = [...tuningPresets(strings).first.tuning];
  });

  void _setPreset(String? name) => setState(() {
    _preset = name;
    if (name != null) {
      _tuning = [
        ...tuningPresets(_strings).firstWhere((t) => t.name == name).tuning,
      ];
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tempo = _tempoValue;
    final canCreate = _title.text.trim().isNotEmpty && tempo != null;
    final (numerator, denominator) =
        _timeSignature ?? (_numerator, _denominator);

    Widget field(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(child: child),
        ],
      ),
    );

    return AlertDialog(
      title: Text(l10n.newSong),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(
                l10n.songTitle,
                TextField(
                  key: const Key('title'),
                  controller: _title,
                  autofocus: true,
                ),
              ),
              field(
                l10n.strings,
                SegmentedButton<int>(
                  segments: [
                    for (final n in const [6, 7, 8])
                      ButtonSegment(value: n, label: Text('$n')),
                  ],
                  selected: {_strings},
                  onSelectionChanged: (s) => _setStrings(s.single),
                ),
              ),
              field(
                l10n.tuning,
                DropdownButton<String?>(
                  key: const Key('tuning'),
                  isExpanded: true,
                  value: _preset,
                  items: [
                    for (final preset in tuningPresets(_strings))
                      DropdownMenuItem(
                        value: preset.name,
                        child: Text(preset.name),
                      ),
                    DropdownMenuItem(child: Text(l10n.custom)),
                  ],
                  onChanged: _setPreset,
                ),
              ),
              if (_preset == null)
                for (final (i, note) in _tuning.indexed)
                  field(
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
                      onChanged: (n) => setState(() => _tuning[i] = n!),
                    ),
                  ),
              field(
                l10n.tempoBpm,
                TextField(
                  key: const Key('tempo'),
                  controller: _tempo,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              field(
                l10n.timeSignature,
                DropdownButton<(int, int)?>(
                  key: const Key('timeSignature'),
                  isExpanded: true,
                  value: _timeSignature,
                  items: [
                    for (final (n, d) in _timeSignatures)
                      DropdownMenuItem(value: (n, d), child: Text('$n/$d')),
                    DropdownMenuItem(child: Text(l10n.custom)),
                  ],
                  onChanged: (ts) => setState(() => _timeSignature = ts),
                ),
              ),
              if (_timeSignature == null)
                field(
                  '',
                  Row(
                    children: [
                      DropdownButton<int>(
                        key: const Key('numerator'),
                        value: _numerator,
                        items: [
                          for (var n = 1; n <= 32; n++)
                            DropdownMenuItem(value: n, child: Text('$n')),
                        ],
                        onChanged: (n) => setState(() => _numerator = n!),
                      ),
                      const Text(' / '),
                      DropdownButton<int>(
                        key: const Key('denominator'),
                        value: _denominator,
                        items: [
                          for (final d in _denominators)
                            DropdownMenuItem(value: d, child: Text('$d')),
                        ],
                        onChanged: (d) => setState(() => _denominator = d!),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canCreate
              ? () => Navigator.pop(
                  context,
                  NewSongOptions(
                    title: _title.text.trim(),
                    tuning: _tuning,
                    tempo: tempo,
                    numerator: numerator,
                    denominator: denominator,
                  ),
                )
              : null,
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
