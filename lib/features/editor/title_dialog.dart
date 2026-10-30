import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Pops with the new name, or null when cancelled: the song's title by
/// default, or another name given [heading] and [label].
class TitleDialog extends StatefulWidget {
  final String title;
  final String? heading;
  final String? label;

  const TitleDialog({required this.title, this.heading, this.label, super.key});

  @override
  State<TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<TitleDialog> {
  late final _controller = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.heading ?? l10n.changeTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label ?? l10n.songTitle),
        onSubmitted: (title) => Navigator.pop(context, title),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
