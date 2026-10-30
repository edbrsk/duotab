import 'dart:io';

import 'package:path/path.dart' as p;

import '../editor/owned_files.dart';
import '../editor/song_saver.dart';
import '../playback/practice_store.dart';
import '../score/score_cubit.dart';

enum NameProblem { empty, invalid, taken }

/// Deletes and renames songs in Documents, with what the app keeps about
/// them, around the open song and its autosave.
class SongFiles {
  final Directory documents;
  final ScoreCubit score;
  final SongSaver saver;
  final PracticeStore practice;
  final OwnedFiles owned;

  SongFiles({
    required this.documents,
    required this.score,
    required this.saver,
    required this.practice,
    required this.owned,
  });

  Future<void> delete(String path) async {
    if (score.state.path == path) await score.closeSong();
    // A save already writing would bring the file back.
    await saver.idle;
    final file = File(p.join(documents.path, path));
    if (file.existsSync()) await file.delete();
    await practice.remove(path);
    await owned.remove(path);
  }

  /// Renames the file, keeping its folder and extension; null when done.
  Future<NameProblem?> rename(String path, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return NameProblem.empty;
    if (trimmed.contains(RegExp(r'[/\\:]'))) return NameProblem.invalid;
    final to = p.join(p.dirname(path), '$trimmed${p.extension(path)}');
    final target = p.normalize(to);
    if (target == path) return null;
    // Only the case changing finds the song itself on a case-insensitive disk.
    if (File(p.join(documents.path, target)).existsSync() &&
        target.toLowerCase() != path.toLowerCase()) {
      return NameProblem.taken;
    }
    final open = score.state.path == path;
    if (open) await saver.flush();
    await saver.idle;
    await File(p.join(documents.path, path))
        .rename(p.join(documents.path, target));
    await practice.rename(path, target);
    await owned.rename(path, target);
    if (open) score.moveTo(target);
    return null;
  }
}
