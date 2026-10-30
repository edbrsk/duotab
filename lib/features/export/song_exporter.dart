import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;

import '../../engine/engine_bridge.dart';
import '../score/score_cubit.dart';
import 'export_channel.dart';

enum ExportFormat { gp, pdf }

/// Writes the open song to a temporary file and offers it in the share sheet.
class SongExporter {
  final EngineBridge engine;
  final ScoreCubit score;
  final ExportChannel channel;
  final Directory temporary;

  const SongExporter({
    required this.engine,
    required this.score,
    required this.channel,
    required this.temporary,
  });

  static String fileName(String title, String extension) {
    final name = title.replaceAll(RegExp(r'[/\\:]'), '-').trim();
    return '${name.isEmpty ? 'Untitled' : name}.$extension';
  }

  /// [anchor] is the Export button's rect in global coordinates.
  Future<void> share(ExportFormat format, Rect anchor) async {
    final folder = Directory(p.join(temporary.path, 'exports'));
    // The share sheet has finished with earlier files by now.
    if (folder.existsSync()) await folder.delete(recursive: true);
    await folder.create(recursive: true);
    final title = score.state.song?.title ?? '';
    final file = File(p.join(folder.path, fileName(title, format.name)));
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
