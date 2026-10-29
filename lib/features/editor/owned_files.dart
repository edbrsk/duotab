import '../../core/storage/json_file.dart';

/// Songs the app created or copied, by path relative to Documents: the only
/// files it ever overwrites.
class OwnedFiles {
  final JsonFile file;

  OwnedFiles(this.file);

  Future<bool> owns(String path) async => (await _paths()).contains(path);

  Future<void> add(String path) async {
    final paths = await _paths();
    if (paths.add(path)) await file.write({'paths': paths.toList()});
  }

  Future<Set<String>> _paths() async => {
    ...((await file.read())['paths'] as List<dynamic>? ?? [])
        .whereType<String>(),
  };
}
