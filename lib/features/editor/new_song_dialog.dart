import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import 'tuning_fields.dart';
import 'tuning_presets.dart';

const _timeSignatures = [(4, 4), (3, 4), (6, 8), (7, 8), (5, 4), (12, 8)];
const _denominators = [1, 2, 4, 8, 16, 32];

/// Pops the [NewSongOptions] chosen, or null when cancelled.
class NewSongDialog extends StatefulWidget {
  const NewSongDialog({super.key});

  @override
  State<NewSongDialog> createState() => _NewSongDialogState();
}

class _NewSongDialogState extends State<NewSongDialog> {
  final _title = TextEditingController();
  final _tempo = TextEditingController(text: '120');
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tempo = _tempoValue;
    final canCreate = _title.text.trim().isNotEmpty && tempo != null;
    final (numerator, denominator) =
        _timeSignature ?? (_numerator, _denominator);

    const field = labelledField;

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
              TuningFields(onChanged: (t) => setState(() => _tuning = t)),
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
