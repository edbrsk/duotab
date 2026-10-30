import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../engine/engine_bridge.dart';
import '../../engine/protocol.dart';
import '../import/unique_destination.dart';
import '../score/score_cubit.dart';
import 'owned_files.dart';

class SongNotCreated implements Exception {
  final String path;

  const SongNotCreated(this.path);

  @override
  String toString() => 'SongNotCreated: $path';
}

/// Saves the open song as `.gp`. An opened file is never written: the first
/// save goes to a "(DuoTab)" copy beside it, and later saves to that copy.
class SongSaver {
  final Directory documents;
  final EngineBridge engine;
  final ScoreCubit score;
  final OwnedFiles owned;
  final Future<void> Function() onSaved;
  final Duration delay;
  Timer? _timer;
  Future<void> _saves = Future.value();
  var _dirty = false;
  late int _openId;
  late final StreamSubscription<ScoreState> _songs;

  SongSaver({
    required this.documents,
    required this.engine,
    required this.score,
    required this.owned,
    required this.onSaved,
    this.delay = const Duration(seconds: 1),
  }) {
    _openId = score.state.openId;
    // Another song, or the same file reopened after an engine restart: the
    // engine no longer holds the edits a pending save was for.
    _songs = score.stream.listen((state) {
      if (state.openId == _openId) return;
      _openId = state.openId;
      _timer?.cancel();
      _dirty = false;
    });
  }

  /// Saves once edits pause for [delay].
  void schedule() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Saves a pending edit now: before another song opens, or when the app is
  /// hidden.
  Future<void> flush() => _dirty ? saveNow() : Future.value();

  /// Done when no save is writing.
  Future<void> get idle => _saves;

  /// One at a time, so two saves cannot both make a copy.
  Future<void> saveNow() {
    _timer?.cancel();
    final save = _saves.then((_) => _save());
    _saves = save.then<void>((_) {}, onError: (Object _) {});
    return save;
  }

  Future<void> _save() async {
    final path = score.state.path;
    final openId = score.state.openId;
    if (path == null) return;
    _dirty = false;
    try {
      final bytes = await engine.exportGp();
      // The export may be of a song opened since; it must not land in this one.
      if (score.state.openId != openId) return;
      if (await owned.owns(path)) {
        await _write(File(p.join(documents.path, path)), bytes);
      } else {
        final folder = Directory(p.join(documents.path, p.dirname(path)));
        final copy = uniqueDestination(
          folder,
          '${p.basenameWithoutExtension(path)} (DuoTab).gp',
        );
        await _write(copy, bytes);
        final copyPath = p.relative(copy.path, from: documents.path);
        await owned.add(copyPath);
        score.moveTo(copyPath);
      }
      await onSaved();
    } on Object catch (e) {
      // Kept pending: the next edit or flush tries again.
      debugPrint('SongSaver: could not save $path: $e');
      if (score.state.openId == openId) _dirty = true;
    }
  }

  /// A temporary file renamed over the target, so a save cut short never
  /// leaves a truncated song.
  static Future<void> _write(File file, List<int> bytes) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }

  /// Creates a song in the app, saved as `<title>.gp`.
  Future<String> createSong(NewSongOptions options) async {
    await flush();
    final name = options.title.replaceAll(RegExp(r'[/\\:]'), '-').trim();
    final file = uniqueDestination(
      documents,
      '${name.isEmpty ? 'Untitled' : name}.gp',
    );
    final path = p.relative(file.path, from: documents.path);
    await score.create(options, path);
    if (score.state.path != path) {
      // The engine refused the song; the claimed file must not stay empty.
      await file.delete();
      throw SongNotCreated(path);
    }
    await owned.add(path);
    await saveNow();
    return path;
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_songs.cancel());
  }
}
