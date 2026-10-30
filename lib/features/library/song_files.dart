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

  /// Renames the file, keeping its folder and extension; null when done. An
  /// edited copy renames its [original] with it, so the two stay a pair.
  Future<NameProblem?> rename(
    String path,
    String name, {
    String? original,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return NameProblem.empty;
    if (trimmed.contains(RegExp(r'[/\\:]'))) return NameProblem.invalid;
    final moves = <(String, String)>[
      if (original != null) (original, _renamed(original, trimmed)),
      (path, _renamed(path, _copyName(path, original, trimmed))),
    ];
    for (final (from, to) in moves) {
      // Only the case changing finds the song itself on a case-insensitive disk.
      if (to != from &&
          File(p.join(documents.path, to)).existsSync() &&
          to.toLowerCase() != from.toLowerCase()) {
        return NameProblem.taken;
      }
    }
    for (final (from, to) in moves) {
      if (to != from) await _move(from, to);
    }
    return null;
  }

  static String _renamed(String path, String name) =>
      p.normalize(p.join(p.dirname(path), '$name${p.extension(path)}'));

  /// A copy named after its original keeps what follows that name, such as
  /// " (DuoScore) (2)".
  static String _copyName(String copy, String? original, String name) {
    final copyName = p.basenameWithoutExtension(copy);
    final originalName = original == null
        ? null
        : p.basenameWithoutExtension(original);
    if (originalName == null || !copyName.startsWith(originalName)) {
      return name;
    }
    return '$name${copyName.substring(originalName.length)}';
  }

  Future<void> _move(String from, String to) async {
    final open = score.state.path == from;
    if (open) await saver.flush();
    await saver.idle;
    await File(p.join(documents.path, from)).rename(p.join(documents.path, to));
    await practice.rename(from, to);
    await owned.rename(from, to);
    if (open) score.moveTo(to);
  }
}
