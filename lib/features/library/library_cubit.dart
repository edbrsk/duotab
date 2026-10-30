import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../engine/engine_bridge.dart';
import '../editor/owned_files.dart';
import 'song_list_entry.dart';

const supportedSongExtensions = {
  '.gp3',
  '.gp4',
  '.gp5',
  '.gpx',
  '.gp',
  '.musicxml',
  '.xml',
  '.mxl',
};

class LibraryState {
  final bool loading;
  final List<SongListEntry> songs;

  const LibraryState({required this.loading, required this.songs});
}

final _copyName = RegExp(r'^(.*) \(DuoScore\)( \(\d+\))?$');

/// Each edited copy and the opened file it was made from, both in [paths].
/// Copies made before the app recorded their original pair by name: an owned
/// `X (DuoScore).gp` with an unowned `X` song beside it.
Map<String, String> pairCopies(
  List<String> paths,
  Set<String> owned,
  Map<String, String> recorded,
) {
  final present = paths.toSet();
  final pairs = <String, String>{};
  for (final copy in paths) {
    if (!owned.contains(copy)) continue;
    final original =
        recorded[copy] ??
        switch (_copyName.firstMatch(p.basenameWithoutExtension(copy))) {
          final match? =>
            paths
                .where(
                  (o) =>
                      !owned.contains(o) &&
                      p.dirname(o) == p.dirname(copy) &&
                      p.basenameWithoutExtension(o) == match.group(1),
                )
                .firstOrNull,
          null => null,
        };
    if (original != null &&
        present.contains(original) &&
        !owned.contains(original)) {
      pairs[copy] = original;
    }
  }
  return pairs;
}

class LibraryCubit extends Cubit<LibraryState> {
  final Directory documents;
  final EngineBridge engine;
  final OwnedFiles owned;
  final _cache = <String, ({DateTime modified, SongListEntry entry})>{};

  LibraryCubit({
    required this.documents,
    required this.engine,
    required this.owned,
  }) : super(const LibraryState(loading: false, songs: []));

  Future<void> refresh() async {
    emit(LibraryState(loading: true, songs: state.songs));
    final files = documents.listSync().whereType<File>().where(
      (f) =>
          supportedSongExtensions.contains(p.extension(f.path).toLowerCase()),
    );
    // All at once, so a stalled engine costs one timeout, not one per file.
    final summarized = await Future.wait([
      for (final file in files) _entryFor(file),
    ]);
    final paths = summarized.map((e) => e.path).toSet();
    _cache.removeWhere((path, _) => !paths.contains(path));
    final pairs = pairCopies(
      (paths.toList()..sort()),
      await owned.all(),
      await owned.originals(),
    );
    // The original stays as a backup; its copy is the song the owner edits.
    // The first copy by name, `X (DuoScore)`, takes the original's name.
    summarized.sort(
      (a, b) =>
          p.withoutExtension(a.path).compareTo(p.withoutExtension(b.path)),
    );
    final named = <String>{};
    final entries = [
      for (final entry in summarized)
        if (pairs[entry.path] case final original?)
          entry.standingFor(original, named: named.add(original))
        else if (!pairs.containsValue(entry.path))
          entry,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!isClosed) emit(LibraryState(loading: false, songs: entries));
  }

  Future<SongListEntry> _entryFor(File file) async {
    final path = p.relative(file.path, from: documents.path);
    final modified = file.lastModifiedSync();
    final cached = _cache[path];
    if (cached != null && cached.modified == modified) return cached.entry;
    final (entry, cacheable) = await _summarize(path);
    if (cacheable) _cache[path] = (modified: modified, entry: entry);
    return entry;
  }

  /// The entry, and whether it may be cached: a timeout says nothing about
  /// the file, so it is asked about again on the next refresh.
  Future<(SongListEntry, bool)> _summarize(String path) async {
    try {
      final song = await engine.summarize(path);
      final guitar = song.guitarTracks.firstOrNull;
      final entry = SongListEntry(
        path: path,
        name: p.basenameWithoutExtension(path),
        tuningLabel: guitar?.tuning == null
            ? null
            : tuningLabel(guitar!.tuning!),
        stringCount: guitar?.stringCount,
        readable: true,
      );
      return (entry, true);
    } on Object catch (e) {
      final entry = SongListEntry(
        path: path,
        name: p.basenameWithoutExtension(path),
        tuningLabel: null,
        stringCount: null,
        readable: false,
      );
      return (entry, e is! EngineTimeout);
    }
  }
}
