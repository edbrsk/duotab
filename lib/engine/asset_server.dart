import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

const _contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.svg': 'image/svg+xml',
  '.eot': 'application/vnd.ms-fontobject',
};

/// Serves the engine page to the web view on the loopback interface, plus
/// the Documents folder read-only so the engine can fetch songs. WebKit
/// refuses alphaTab's module, worker and worklet from `file://`.
///
/// Any app or web page on the phone can reach the loopback port, so every
/// path starts with a token made for this launch, and a request naming
/// another host (a DNS-rebinding page) is refused.
class AssetServer {
  final HttpServer _server;
  final Directory _engineAssets;
  final Directory _documents;
  final String _token;

  AssetServer._(
    this._server,
    this._engineAssets,
    this._documents,
    this._token,
  ) {
    _server.listen(_handle);
  }

  static Future<AssetServer> start({
    required Directory engineAssets,
    required Directory documents,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    return AssetServer._(server, engineAssets, documents, token);
  }

  /// The path every route sits under.
  String get root => '/$_token';

  Uri get engineUri => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: _server.port,
    path: '$root/engine/index.html',
  );

  Uri songUri(String documentsRelativePath) =>
      engineUri.replace(path: '$root/songs/$documentsRelativePath');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    final headers = request.headers;
    if (headers.host != '127.0.0.1' || headers.port != _server.port) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }
    final segments = request.uri.pathSegments;
    final file = segments.firstOrNull == _token
        ? _resolve(segments.skip(1).toList())
        : null;
    if (file == null || !file.existsSync()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      _contentTypes[p.extension(file.path).toLowerCase()] ??
          'application/octet-stream',
    );
    await response.addStream(file.openRead());
    await response.close();
  }

  File? _resolve(List<String> segments) {
    if (segments.length < 2) return null;
    final root = switch (segments.first) {
      'engine' => _engineAssets,
      'songs' => _documents,
      _ => null,
    };
    if (root == null) return null;
    final path = p.normalize(p.joinAll([root.path, ...segments.skip(1)]));
    return p.isWithin(root.path, path) ? File(path) : null;
  }
}
