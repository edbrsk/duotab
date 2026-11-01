import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'cursor_keys.dart';
import 'editor_cubit.dart';
import 'pad_key.dart';

/// Undo, redo and the cursor keys, fixed under the track panel's parts.
class EditStrip extends StatelessWidget {
  const EditStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final (canUndo, canRedo) = context.select<EditorCubit, (bool, bool)>(
      (c) => (c.state.canUndo, c.state.canRedo),
    );
    Widget key(IconData icon, String tooltip, VoidCallback? onPressed) =>
        Expanded(
          child: Opacity(
            opacity: onPressed == null ? 0.4 : 1,
            child: PadKey(icon: icon, tooltip: tooltip, onPressed: onPressed),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            key(Icons.undo, l10n.undo, canUndo ? editor.undo : null),
            const SizedBox(width: Spacing.xs),
            key(Icons.redo, l10n.redo, canRedo ? editor.redo : null),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        const CursorKeys(),
      ],
    );
  }
}
