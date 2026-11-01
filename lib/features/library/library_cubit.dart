import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../engine/engine_bridge.dart';
import '../editor/owned_files.dart';
import 'added_dates.dart';
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

/// Recorded copies whose original is still in [paths], beside them.
Map<String, String> recordedPairs(
  List<String> paths,
  Set<String> owned,
  Map<String, String> recorded,
) {
  final present = paths.toSet();
  return {
    for (final MapEntry(key: copy, value: original) in recorded.entries)
      if (present.contains(copy) &&
          owned.contains(copy) &&
          present.contains(original) &&
          !owned.contains(original))
        copy: original,
  };
}

/// Copies made before the app recorded their original, paired by name: an
/// owned `X (DuoScore).gp` with exactly one unowned `X` song beside it.
Map<String, String> namePairs(
  List<String> paths,
  Set<String> owned,
  Map<String, String> recorded,
) {
  final pairs = <String, String>{};
  for (final copy in paths) {
    if (!owned.contains(copy) || recorded.containsKey(copy)) continue;
    final match = _copyName.firstMatch(p.basenameWithoutExtension(copy));
    if (match == null) continue;
    final candidates = paths.where(
      (o) =>
          !owned.contains(o) &&
          p.dirname(o) == p.dirname(copy) &&
          p.basenameWithoutExtension(o) == match.group(1),
    );
    if (candidates.length == 1) pairs[copy] = candidates.single;
  }
  return pairs;
}

class LibraryCubit extends Cubit<LibraryState> {
  final Directory documents;
  final EngineBridge engine;
  final OwnedFiles owned;
  final AddedDates dates;
  final _cache = <String, ({DateTime modified, SongListEntry entry})>{};

  LibraryCubit({
    required this.documents,
    required this.engine,
    required this.owned,
    required this.dates,
  }) : super(const LibraryState(loading: false, songs: []));

  Future<void>? _refreshing;
  var _again = false;

  /// Refreshes asked for while one runs wait for it and share one more run,
  /// which sees what changed meanwhile.
  Future<void> refresh() {
    if (_refreshing case final running?) {
      _again = true;
      return running;
    }
    return _refreshing = () async {
      try {
        do {
          _again = false;
          await _refresh();
        } while (_again && !isClosed);
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<void> _refresh() async {
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
    final sorted = paths.toList()..sort();
    try {
      await owned.forgetMissing(
        (path) => File(p.join(documents.path, path)).existsSync(),
      );
    } on Object catch (e) {
      // The songs are still listed; the record is cleaned up next time.
      debugPrint('LibraryCubit: could not update the app-made files: $e');
    }
    final ownedPaths = await owned.all();
    // Once, for copies made before the app recorded them: a match by name
    // later could hide, and then delete, another song the owner imported.
    if (!await owned.pairedByName()) {
      final named = namePairs(sorted, ownedPaths, await owned.originals());
      for (final MapEntry(key: copy, value: original) in named.entries) {
        await owned.addCopy(copy, of: original);
      }
      await owned.markPairedByName();
    }
    final pairs = recordedPairs(sorted, ownedPaths, await owned.originals());
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
    await _newestFirst(entries, sorted);
    if (!isClosed) emit(LibraryState(loading: false, songs: entries));
  }

  /// Songs that arrived together stay in name order. An edited song takes
  /// its original's date, so editing never moves it.
  Future<void> _newestFirst(
    List<SongListEntry> entries,
    List<String> paths,
  ) async {
    final Map<String, DateTime> added;
    try {
      added = await dates.datesFor(paths, (path) {
        try {
          return File(p.join(documents.path, path)).lastModifiedSync();
        } on FileSystemException {
          return DateTime.now();
        }
      });
    } on Object catch (e) {
      // The songs are still listed, by name.
      debugPrint('LibraryCubit: could not read when songs arrived: $e');
      return;
    }
    DateTime arrived(SongListEntry entry) =>
        added[entry.original ?? entry.path] ?? DateTime.now();
    entries.sort((a, b) {
      final newer = arrived(b).compareTo(arrived(a));
      return newer != 0
          ? newer
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
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
