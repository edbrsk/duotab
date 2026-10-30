import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Pops with the new title, or null when cancelled.
class TitleDialog extends StatefulWidget {
  final String title;

  const TitleDialog({required this.title, super.key});

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
      title: Text(l10n.changeTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.songTitle),
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
