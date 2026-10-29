import 'dart:async';
import 'dart:io';

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

  SongSaver({
    required this.documents,
    required this.engine,
    required this.score,
    required this.owned,
    required this.onSaved,
    this.delay = const Duration(seconds: 1),
  });

  /// Saves once edits pause for [delay].
  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(saveNow()));
  }

  /// One at a time, so two saves cannot both make a copy.
  Future<void> saveNow() {
    _timer?.cancel();
    final save = _saves.then((_) => _save());
    _saves = save.then<void>((_) {}, onError: (Object _) {});
    return save;
  }

  Future<void> _save() async {
    final path = score.state.path;
    if (path == null) return;
    final bytes = await engine.exportGp();
    if (await owned.owns(path)) {
      await File(p.join(documents.path, path)).writeAsBytes(bytes, flush: true);
    } else {
      final folder = Directory(p.join(documents.path, p.dirname(path)));
      final copy = uniqueDestination(
        folder,
        '${p.basenameWithoutExtension(path)} (DuoTab).gp',
      );
      await copy.writeAsBytes(bytes, flush: true);
      final copyPath = p.relative(copy.path, from: documents.path);
      await owned.add(copyPath);
      score.moveTo(copyPath);
    }
    await onSaved();
  }

  /// Creates a song in the app, saved as `<title>.gp`.
  Future<String> createSong(NewSongOptions options) async {
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
}
