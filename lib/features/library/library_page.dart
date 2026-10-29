import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'library_cubit.dart';
import 'song_list_entry.dart';

class LibraryPage extends StatefulWidget {
  final void Function(String path) onOpen;

  const LibraryPage({required this.onOpen, super.key});

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
                  // Enabled once the editor exists (Plan 3).
                  FilledButton.icon(
                    onPressed: null,
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
                          _SongTile(entry: entry, onOpen: widget.onOpen),
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

  const _SongTile({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = [
      ?entry.tuningLabel,
      if (entry.stringCount case final count?) l10n.stringsCount(count),
    ];
    return ListTile(
      leading: Icon(entry.readable ? Icons.music_note : Icons.error_outline),
      title: Text(entry.title),
      subtitle: Text(
        entry.readable ? details.join(' · ') : l10n.unreadableFile,
      ),
      enabled: entry.readable,
      onTap: entry.readable ? () => onOpen(entry.path) : null,
    );
  }
}
