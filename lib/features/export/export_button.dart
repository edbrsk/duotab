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
      return const SizedBox.square(
        dimension: kMinInteractiveDimension,
        child: Center(
          child: SizedBox.square(
            dimension: IconSizes.md,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return PopupMenuButton<ExportFormat>(
      tooltip: l10n.export,
      icon: const Icon(Icons.ios_share, color: AppColors.accent),
      onSelected: _export,
      itemBuilder: (_) => [
        PopupMenuItem(value: ExportFormat.gp, child: Text(l10n.exportGp)),
        PopupMenuItem(
          value: ExportFormat.pdf,
          enabled: widget.canExportPdf,
          child: Text(l10n.exportPdf),
        ),
      ],
    );
  }
}
