import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'tuning_fields.dart';
import 'tuning_presets.dart';

typedef RetuneChoice = ({List<int> tuning, bool keepFrets});

/// Picks a track's new tuning and what the retune keeps; pops the choice, or
/// null when cancelled.
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
  var _keepFrets = false;

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
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.keepSound)),
                  ButtonSegment(value: true, label: Text(l10n.keepFrets)),
                ],
                selected: {_keepFrets},
                onSelectionChanged: (s) =>
                    setState(() => _keepFrets = s.single),
              ),
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(
                  _keepFrets ? l10n.retuneHintFrets : l10n.retuneHint,
                ),
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
          onPressed: () =>
              Navigator.of(context)
                  .pop<RetuneChoice>((tuning: _tuning, keepFrets: _keepFrets)),
          child: Text(l10n.retuneConfirm),
        ),
      ],
    );
  }
}
