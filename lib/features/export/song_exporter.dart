import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;

import '../../engine/engine_bridge.dart';
import '../editor/song_saver.dart';
import '../playback/practice_store.dart';
import '../score/score_cubit.dart';
import 'export_channel.dart';

enum ExportFormat { gp, pdf }

/// Writes the open song to a temporary file and offers it in the share sheet.
class SongExporter {
  final EngineBridge engine;
  final ScoreCubit score;
  final ExportChannel channel;
  final Directory temporary;
  final Directory documents;
  final SongSaver saver;
  final PracticeStore practice;

  const SongExporter({
    required this.engine,
    required this.score,
    required this.channel,
    required this.temporary,
    required this.documents,
    required this.saver,
    required this.practice,
    this.now = DateTime.now,
  });

  final DateTime Function() now;

  static const _maxNameBytes = 200;

  /// The share sheet takes this long at most to finish with a file.
  static const _keepExports = Duration(minutes: 10);

  /// A name the Files app shows: no path characters, no leading dot (a
  /// hidden file), and short enough for the file system.
  static String fileName(String title, String extension) {
    var name = title
        .replaceAll(RegExp(r'[/\\:]'), '-')
        .trim()
        .replaceFirst(RegExp(r'^\.+'), '')
        .trim();
    while (utf8.encode(name).length > _maxNameBytes) {
      name = String.fromCharCodes(name.runes.toList()..removeLast())
          .trimRight();
    }
    return '${name.isEmpty ? 'Untitled' : name}.$extension';
  }

  /// Each export has its own folder, so two at once never meet. Folders
  /// older than the share sheet could still be using go.
  Future<File> _exportFile(String name, ExportFormat format) async {
    final exports = Directory(p.join(temporary.path, 'exports'));
    final time = now();
    if (exports.existsSync()) {
      for (final old in exports.listSync().whereType<Directory>()) {
        final made = int.tryParse(p.basename(old.path));
        if (made == null ||
            time.difference(DateTime.fromMicrosecondsSinceEpoch(made)) >
                _keepExports) {
          await old.delete(recursive: true);
        }
      }
    }
    final folder = Directory(
      p.join(exports.path, '${time.microsecondsSinceEpoch}'),
    );
    await folder.create(recursive: true);
    return File(p.join(folder.path, fileName(name, format.name)));
  }

  /// The song file at [path] (relative to Documents), not the open one,
  /// shared as [name]. A `.gp` file goes as it is; PDF prints its first
  /// guitar track with the staves chosen for it.
  Future<void> shareFile(
    String path,
    String name,
    ExportFormat format,
    Rect anchor,
  ) async {
    // The open song's file may be behind its edits, and its first edit makes
    // the copy that holds them.
    final open = score.state.path == path;
    await saver.flush();
    await saver.idle;
    final source = open ? score.state.path ?? path : path;
    final file = await _exportFile(name, format);
    switch (format) {
      case ExportFormat.gp:
        if (p.extension(source).toLowerCase() == '.gp') {
          await File(p.join(documents.path, source)).copy(file.path);
        } else {
          await file.writeAsBytes(
            await engine.exportFileGp(source),
            flush: true,
          );
        }
      case ExportFormat.pdf:
        final tracks = (await practice.load(source))?.tracks ?? const {};
        final pages = await engine.exportFilePdf(source, [
          for (final MapEntry(key: index, value: track) in tracks.entries)
            track.staves(index),
        ]);
        await channel.makePdf(
          pages: pages.pages,
          baseUrl: pages.baseUrl,
          path: file.path,
        );
    }
    await channel.share([file.path], anchor);
  }

  /// [anchor] is the Export button's rect in global coordinates.
  Future<void> share(ExportFormat format, Rect anchor) async {
    final file = await _exportFile(score.state.song?.title ?? '', format);
    switch (format) {
      case ExportFormat.gp:
        await file.writeAsBytes(await engine.exportGp(), flush: true);
      case ExportFormat.pdf:
        final pages = await engine.exportPdf();
        await channel.makePdf(
          pages: pages.pages,
          baseUrl: pages.baseUrl,
          path: file.path,
        );
    }
    await channel.share([file.path], anchor);
  }
}
