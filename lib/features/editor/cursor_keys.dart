import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import 'editor_cubit.dart';
import 'pad_key.dart';

/// ◀ ▲ ▼ ▶, shared by the fret pad and the chord picker.
class CursorKeys extends StatelessWidget {
  const CursorKeys({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = context.select<EditorCubit, bool>(
      (c) => c.state.position != null,
    );
    final keys = [
      (Icons.chevron_left, l10n.previousBeat, 'left'),
      (Icons.keyboard_arrow_up, l10n.stringUp, 'up'),
      (Icons.keyboard_arrow_down, l10n.stringDown, 'down'),
      (Icons.chevron_right, l10n.nextBeat, 'right'),
    ];
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Row(
          children: [
            for (final (i, (icon, tooltip, direction)) in keys.indexed) ...[
              if (i > 0) const SizedBox(width: Spacing.xs),
              Expanded(
                child: PadKey(
                  icon: icon,
                  tooltip: tooltip,
                  onPressed: () =>
                      context.read<EditorCubit>().command(Move(direction)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
