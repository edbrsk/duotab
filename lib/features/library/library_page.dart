import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../editor/new_song_dialog.dart';
import 'library_cubit.dart';
import 'song_files.dart';
import 'song_list_entry.dart';

class LibraryPage extends StatefulWidget {
  final void Function(String path) onOpen;
  final Future<void> Function(NewSongOptions options) onNewSong;
  final Future<void> Function(String path) onDelete;

  /// Null when renamed.
  final Future<NameProblem?> Function(String path, String name) onRename;

  const LibraryPage({
    required this.onOpen,
    required this.onNewSong,
    required this.onDelete,
    required this.onRename,
    super.key,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Files added in the Files app show up when the app comes back.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<LibraryCubit>().refresh(),
    );
    context.read<LibraryCubit>().refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _delete(SongListEntry entry) async {
    final library = context.read<LibraryCubit>();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSongQuestion(entry.name)),
        content: Text(l10n.deleteSongBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onDelete(entry.path);
    await library.refresh();
  }

  Future<void> _rename(SongListEntry entry) async {
    final library = context.read<LibraryCubit>();
    final renamed = await showDialog<bool>(
      context: context,
      builder: (_) => _RenameDialog(
        name: entry.name,
        onRename: (name) => widget.onRename(entry.path, name),
      ),
    );
    if (renamed == true) await library.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<LibraryCubit>().state;
    // ListTile ink needs a Material ancestor wherever the page is placed.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tabLibrary,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final options = await showDialog<NewSongOptions>(
                        context: context,
                        builder: (_) => const NewSongDialog(),
                      );
                      if (options != null) await widget.onNewSong(options);
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newSong),
                  ),
                ],
              ),
            ),
            if (state.loading && state.songs.isEmpty)
              const LinearProgressIndicator(),
            Expanded(
              child: state.songs.isEmpty && !state.loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Text(
                          l10n.libraryEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final entry in state.songs)
                          _SongTile(
                            entry: entry,
                            onOpen: widget.onOpen,
                            onDelete: () => _delete(entry),
                            onRename: () => _rename(entry),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final SongListEntry entry;
  final void Function(String path) onOpen;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _SongTile({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = [
      ?entry.tuningLabel,
      if (entry.stringCount case final count?) l10n.stringsCount(count),
    ];
    return ListTile(
      leading: Icon(entry.readable ? Icons.music_note : Icons.error_outline),
      title: Text(entry.name),
      subtitle: Text(
        entry.readable ? details.join(' · ') : l10n.unreadableFile,
      ),
      // A broken file can still be renamed or deleted.
      trailing: PopupMenuButton<VoidCallback>(
        tooltip: l10n.songActions,
        icon: const Icon(Icons.more_vert),
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          PopupMenuItem(value: onRename, child: Text(l10n.rename)),
          PopupMenuItem(value: onDelete, child: Text(l10n.delete)),
        ],
      ),
      onTap: entry.readable ? () => onOpen(entry.path) : null,
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String name;

  /// Null when renamed.
  final Future<NameProblem?> Function(String name) onRename;

  const _RenameDialog({required this.name, required this.onRename});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  NameProblem? _problem;
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final problem = await widget.onRename(_controller.text);
    if (!mounted) return;
    if (problem == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _problem = problem;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.renameSong),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.songName,
          errorText: switch (_problem) {
            NameProblem.empty => l10n.nameEmpty,
            NameProblem.invalid => l10n.nameInvalid,
            NameProblem.taken => l10n.nameTaken,
            null => null,
          },
        ),
        onSubmitted: (_) => _busy ? null : _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.rename),
        ),
      ],
    );
  }
}
