import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../engine/engine_bridge.dart';
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

class LibraryCubit extends Cubit<LibraryState> {
  final Directory documents;
  final EngineBridge engine;
  final _cache = <String, ({DateTime modified, SongListEntry entry})>{};

  LibraryCubit({required this.documents, required this.engine})
    : super(const LibraryState(loading: false, songs: []));

  Future<void> refresh() async {
    emit(LibraryState(loading: true, songs: state.songs));
    final files = documents.listSync().whereType<File>().where(
      (f) =>
          supportedSongExtensions.contains(p.extension(f.path).toLowerCase()),
    );
    final entries = <SongListEntry>[];
    for (final file in files) {
      final path = p.relative(file.path, from: documents.path);
      final modified = file.lastModifiedSync();
      final cached = _cache[path];
      if (cached != null && cached.modified == modified) {
        entries.add(cached.entry);
        continue;
      }
      final entry = await _summarize(path);
      _cache[path] = (modified: modified, entry: entry);
      entries.add(entry);
    }
    _cache.removeWhere((path, _) => !entries.any((e) => e.path == path));
    entries.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    if (!isClosed) emit(LibraryState(loading: false, songs: entries));
  }

  Future<SongListEntry> _summarize(String path) async {
    try {
      final song = await engine.summarize(path);
      final guitar = song.guitarTracks.firstOrNull;
      return SongListEntry(
        path: path,
        title: song.title,
        tuningLabel: guitar?.tuning == null
            ? null
            : tuningLabel(guitar!.tuning!),
        stringCount: guitar?.stringCount,
        readable: true,
      );
    } on Exception {
      return SongListEntry(
        path: path,
        title: p.basename(path),
        tuningLabel: null,
        stringCount: null,
        readable: false,
      );
    }
  }
}
