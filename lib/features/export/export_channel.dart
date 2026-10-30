import 'package:flutter/services.dart';

/// iOS renders the engine's pages to PDF and shows the share sheet.
class ExportChannel {
  static const _channel = MethodChannel('dev.edbrsk.duoscore/export');

  const ExportChannel();

  /// [pages] are HTML documents, one per page, loaded relative to [baseUrl].
  /// iOS gives up on a stalled page itself; the timeout keeps the Export
  /// button from waiting forever if it never answers.
  Future<void> makePdf({
    required List<String> pages,
    required String baseUrl,
    required String path,
  }) => _channel
      .invokeMethod<void>('pdf', {
        'pages': pages,
        'baseUrl': baseUrl,
        'path': path,
      })
      .timeout(const Duration(minutes: 2));

  /// [anchor] is in global coordinates: in regular width the sheet is a
  /// popover pointing at it.
  Future<void> share(List<String> paths, Rect anchor) =>
      _channel.invokeMethod<void>('share', {
        'paths': paths,
        'x': anchor.left,
        'y': anchor.top,
        'width': anchor.width,
        'height': anchor.height,
      });
}
