import 'dart:convert';
import 'dart:io';

import 'package:duotab/engine/asset_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AssetServer server;
  late HttpClient client;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('asset_server_test');
    final engine = Directory('${root.path}/engine')..createSync();
    File('${engine.path}/index.html').writeAsStringSync('<html></html>');
    Directory('${engine.path}/alphatab').createSync();
    File('${engine.path}/alphatab/alphaTab.mjs').writeAsStringSync('export {}');
    final documents = Directory('${root.path}/documents')..createSync();
    File('${documents.path}/07 Collateral Damage.gp')
        .writeAsBytesSync([1, 2, 3]);
    File('${root.path}/secret.txt').writeAsStringSync('secret');
    server = await AssetServer.start(
      engineAssets: engine,
      documents: documents,
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
    await root.delete(recursive: true);
  });

  Future<HttpClientResponse> request(String method, String path) async {
    final uri = server.engineUri.replace(path: path);
    final req = await client.openUrl(method, uri);
    return req.close();
  }

  test('serves the engine page and its modules with the right types', () async {
    expect(server.engineUri.host, '127.0.0.1');
    expect(server.engineUri.path, '/engine/index.html');

    final page = await request('GET', '/engine/index.html');
    expect(page.statusCode, 200);
    expect(page.headers.contentType?.mimeType, 'text/html');
    await page.drain<void>();

    final module = await request('GET', '/engine/alphatab/alphaTab.mjs');
    expect(module.headers.contentType?.mimeType, 'text/javascript');
    await module.drain<void>();
  });

  test('serves Documents read-only and refuses paths outside it', () async {
    final song = await client.getUrl(server.songUri('07 Collateral Damage.gp'));
    final response = await song.close();
    expect(response.statusCode, 200);
    expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [
      1,
      2,
      3,
    ]);

    final escape = await request('GET', '/songs/%2E%2E/secret.txt');
    expect(escape.statusCode, 404);
    expect(
      await escape.transform(utf8.decoder).join(),
      isNot(contains('secret')),
    );

    final write = await request('PUT', '/songs/new.gp');
    expect(write.statusCode, 405);
    await write.drain<void>();
  });
}
