import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import 'editor_cubit.dart';
import 'fret_entry.dart';

const _keyHeight = 44.0;

class FretPad extends StatefulWidget {
  const FretPad({super.key});

  @override
  State<FretPad> createState() => _FretPadState();
}

class _FretPadState extends State<FretPad> {
  final _entry = FretEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final enabled = context.select<EditorCubit, bool>(
      (c) => c.state.position != null,
    );

    void send(EditCommand command) {
      if (command is! SetFret) _entry.reset();
      editor.command(command);
    }

    Widget digit(int d) => _Key(
      label: '$d',
      onPressed: () {
        final fret = _entry.digit(d);
        send(SetFret(fret, combine: _entry.combined));
      },
    );
    Widget icon(IconData icon, String tooltip, EditCommand command) =>
        _Key(icon: icon, tooltip: tooltip, onPressed: () => send(command));

    final rows = [
      [digit(1), digit(2), digit(3)],
      [digit(4), digit(5), digit(6)],
      [digit(7), digit(8), digit(9)],
      [
        icon(Icons.chevron_left, l10n.previousBeat, const Move('left')),
        digit(0),
        icon(Icons.chevron_right, l10n.nextBeat, const Move('right')),
      ],
      [
        icon(Icons.keyboard_arrow_up, l10n.stringUp, const Move('up')),
        icon(Icons.backspace_outlined, l10n.deleteNote, const DeleteNote()),
        icon(Icons.keyboard_arrow_down, l10n.stringDown, const Move('down')),
      ],
    ];
    // A digit after the cursor moves starts a new fret.
    return BlocListener<EditorCubit, EditorState>(
      listenWhen: (before, after) => before.position != after.position,
      listener: (_, _) => _entry.reset(),
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Row(
                    children: [
                      for (final (i, key) in row.indexed) ...[
                        if (i > 0) const SizedBox(width: Spacing.xs),
                        Expanded(child: key),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const _Key({required this.onPressed, this.label, this.icon, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final key = Material(
      color: AppColors.key,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: SizedBox(
          height: _keyHeight,
          child: Center(
            child: icon != null
                ? Icon(icon, size: IconSizes.md)
                : Text(label!, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ),
    );
    return tooltip == null ? key : Tooltip(message: tooltip, child: key);
  }
}
