import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../editor/new_song_dialog.dart';
import '../export/song_exporter.dart';
import 'library_cubit.dart';
import 'song_files.dart';
import 'song_list_entry.dart';

class LibraryPage extends StatefulWidget {
  final void Function(String path) onOpen;
  final Future<void> Function(NewSongOptions options) onNewSong;
  final Future<void> Function(String path) onDelete;
  final Future<void> Function() onImport;

  /// Null when renamed; an edited copy passes its `original` to rename too.
  final Future<NameProblem?> Function(
    String path,
    String name, {
    String? original,
  })
  onRename;

  /// `anchor` is the song's menu button, which the share sheet points at.
  final Future<void> Function(
    SongListEntry entry,
    ExportFormat format,
    Rect anchor,
  )
  onExport;

  const LibraryPage({
    required this.onOpen,
    required this.onNewSong,
    required this.onDelete,
    required this.onRename,
    required this.onImport,
    required this.onExport,
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

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Another edited copy still stands for [entry]'s original.
  bool _sharesOriginal(SongListEntry entry) => context
      .read<LibraryCubit>()
      .state
      .songs
      .any((e) => e.path != entry.path && e.original == entry.original);

  /// Runs a change to the song files, then lists the songs as they are,
  /// whether or not it got through.
  Future<void> _change(Future<void> Function() change) async {
    final library = context.read<LibraryCubit>();
    try {
      await change();
    } on Object catch (e) {
      _reportFailure(e);
    } finally {
      await library.refresh();
    }
  }

  void _reportFailure(Object e) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.songChangeFailed('$e'))));
  }

  Future<void> _delete(SongListEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final withOriginal = entry.original != null && !_sharesOriginal(entry);
    final confirmed = await _confirm(
      title: l10n.deleteSongQuestion(entry.name),
      body: withOriginal ? l10n.deleteEditedBody : l10n.deleteSongBody,
      action: l10n.delete,
    );
    if (!confirmed) return;
    await _change(() async {
      await widget.onDelete(entry.path);
      if (withOriginal) await widget.onDelete(entry.original!);
    });
  }

  /// Deletes the edited copy; the original it stood for is listed again,
  /// unless another copy stands for it.
  Future<void> _revert(SongListEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      title: l10n.revertSongQuestion(entry.name),
      body: _sharesOriginal(entry) ? l10n.deleteSongBody : l10n.revertSongBody,
      action: l10n.revert,
    );
    if (!confirmed) return;
    await _change(() => widget.onDelete(entry.path));
  }

  Future<void> _rename(SongListEntry entry) async {
    Object? failure;
    await showDialog<bool>(
      context: context,
      builder: (_) => _RenameDialog(
        name: entry.name,
        // A failed move closes the dialog; the library then says so.
        onRename: (name) async {
          try {
            return await widget.onRename(
              entry.path,
              name,
              original: entry.original,
            );
          } on Object catch (e) {
            failure = e;
            return null;
          }
        },
      ),
    );
    if (!mounted) return;
    if (failure case final e?) _reportFailure(e);
    await context.read<LibraryCubit>().refresh();
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
                  OutlinedButton.icon(
                    onPressed: widget.onImport,
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(l10n.importSongs),
                  ),
                  const SizedBox(width: Spacing.sm),
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
                            key: ValueKey(entry.path),
                            entry: entry,
                            onOpen: widget.onOpen,
                            onDelete: () => _delete(entry),
                            onRename: () => _rename(entry),
                            onRevert: () => _revert(entry),
                            onExport: (format, anchor) =>
                                widget.onExport(entry, format, anchor),
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

class _SongTile extends StatefulWidget {
  final SongListEntry entry;
  final void Function(String path) onOpen;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onRevert;
  final Future<void> Function(ExportFormat format, Rect anchor) onExport;

  const _SongTile({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
    required this.onRevert,
    required this.onExport,
    super.key,
  });

  @override
  State<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<_SongTile> {
  final _menu = GlobalKey();
  var _exporting = false;

  Future<void> _export(ExportFormat format) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final box = _menu.currentContext!.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exporting = true);
    try {
      await widget.onExport(format, anchor);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entry = widget.entry;
    final details = [
      if (entry.original != null) l10n.edited,
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
      trailing: SizedBox.square(
        key: _menu,
        dimension: kMinInteractiveDimension,
        child: _exporting
            ? const Center(
                child: SizedBox.square(
                  dimension: IconSizes.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : PopupMenuButton<VoidCallback>(
                tooltip: l10n.songActions,
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: widget.onRename,
                    child: Text(l10n.rename),
                  ),
                  PopupMenuItem(
                    enabled: entry.readable,
                    value: () => _export(ExportFormat.gp),
                    child: Text(l10n.exportAsGp),
                  ),
                  PopupMenuItem(
                    // The PDF prints the first guitar track.
                    enabled: entry.readable && entry.stringCount != null,
                    value: () => _export(ExportFormat.pdf),
                    child: Text(l10n.exportAsPdf),
                  ),
                  if (entry.original != null)
                    PopupMenuItem(
                      value: widget.onRevert,
                      child: Text(l10n.revertToOriginal),
                    ),
                  PopupMenuItem(
                    value: widget.onDelete,
                    child: Text(l10n.delete),
                  ),
                ],
              ),
      ),
      onTap: entry.readable ? () => widget.onOpen(entry.path) : null,
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
