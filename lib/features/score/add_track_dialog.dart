import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../editor/tuning_fields.dart';
import '../editor/tuning_presets.dart';

/// Pops the new track's tuning, top string first, or null when cancelled.
class AddTrackDialog extends StatefulWidget {
  /// Where the fields start: the drawn track's tuning, when they can show it.
  final List<int>? tuning;

  const AddTrackDialog({this.tuning, super.key});

  @override
  State<AddTrackDialog> createState() => _AddTrackDialogState();
}

class _AddTrackDialogState extends State<AddTrackDialog> {
  late var _tuning = switch (widget.tuning) {
    final tuning? when TuningFields.fits(tuning) => [...tuning],
    _ => [...tuningPresets(6).first.tuning],
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addTrack),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: TuningFields(
            initial: widget.tuning,
            onChanged: (t) => setState(() => _tuning = t),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _tuning),
          child: Text(l10n.add),
        ),
      ],
    );
  }
}
