import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import 'editor_cubit.dart';
import 'fret_entry.dart';
import 'pad_key.dart';

class FretPad extends StatefulWidget {
  const FretPad({super.key});

  @override
  State<FretPad> createState() => _FretPadState();
}

class _FretPadState extends State<FretPad> {
  final _entry = FretEntry();

  /// An arrow that can't move still starts a new fret.
  late final StreamSubscription<EditCommand> _sent;

  @override
  void initState() {
    super.initState();
    _sent = context.read<EditorCubit>().sent.listen((command) {
      if (command is! SetFret) _entry.reset();
    });
  }

  @override
  void dispose() {
    _sent.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = context.read<EditorCubit>();
    final enabled = context.select<EditorCubit, bool>(
      (c) => c.state.position != null,
    );

    void send(EditCommand command) => editor.command(command);

    Widget digit(int d) => PadKey(
      label: '$d',
      onPressed: () {
        final fret = _entry.digit(d);
        send(SetFret(fret, combine: _entry.combined));
      },
    );

    final rows = [
      [digit(1), digit(2), digit(3)],
      [digit(4), digit(5), digit(6)],
      [digit(7), digit(8), digit(9)],
      [
        PadKey(
          icon: Icons.backspace_outlined,
          tooltip: l10n.deleteNote,
          onPressed: () => send(const DeleteNote()),
        ),
        digit(0),
        const SizedBox.shrink(),
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
