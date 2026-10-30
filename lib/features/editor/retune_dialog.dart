import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'tuning_fields.dart';
import 'tuning_presets.dart';

/// Picks a track's new tuning; pops it, or null when cancelled.
class RetuneDialog extends StatefulWidget {
  final String trackName;

  /// The track's tuning now, top string first.
  final List<int> tuning;

  const RetuneDialog({
    required this.trackName,
    required this.tuning,
    super.key,
  });

  @override
  State<RetuneDialog> createState() => _RetuneDialogState();
}

class _RetuneDialogState extends State<RetuneDialog> {
  // What the fields show, which is the first 6-string preset for a tuning
  // they cannot show.
  late var _tuning = TuningFields.fits(widget.tuning)
      ? [...widget.tuning]
      : [...tuningPresets(6).first.tuning];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.retuneHeading(widget.trackName)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TuningFields(
                initial: widget.tuning,
                onChanged: (t) => setState(() => _tuning = t),
              ),
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(l10n.retuneHint),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_tuning),
          child: Text(l10n.retuneConfirm),
        ),
      ],
    );
  }
}
