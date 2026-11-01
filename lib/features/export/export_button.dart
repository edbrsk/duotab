import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'export_failure.dart';
import 'song_exporter.dart';

/// Exports the open song as `.gp` or PDF; one export at a time.
class ExportButton extends StatefulWidget {
  /// `anchor` is this button's rect in global coordinates, which the share
  /// sheet points at.
  final Future<void> Function(ExportFormat format, Rect anchor) onExport;
  final bool canExportPdf;

  const ExportButton({
    required this.onExport,
    required this.canExportPdf,
    super.key,
  });

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  var _running = false;

  Future<void> _export(ExportFormat format) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _running = true);
    try {
      await widget.onExport(format, anchor);
    } on Object catch (e) {
      debugPrint('ExportButton: export failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(exportFailureMessage(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_running) {
      return const SizedBox(
        height: kMinInteractiveDimension,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox.square(
            dimension: IconSizes.md,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    // No value: each choice exports at once and the hint comes back.
    return DropdownButton<ExportFormat>(
      hint: Text(l10n.exportChooseFormat),
      isExpanded: true,
      underline: const SizedBox.shrink(),
      onChanged: (format) {
        if (format != null) _export(format);
      },
      items: [
        DropdownMenuItem(value: ExportFormat.gp, child: Text(l10n.exportGp)),
        DropdownMenuItem(
          value: ExportFormat.pdf,
          enabled: widget.canExportPdf,
          child: Text(l10n.exportPdf),
        ),
      ],
    );
  }
}
