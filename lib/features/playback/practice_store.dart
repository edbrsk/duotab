import '../../core/storage/json_file.dart';
import 'practice_settings.dart';

/// Practice settings per song, keyed by the path relative to Documents.
class PracticeStore {
  final JsonFile file;
  Future<void> _saves = Future.value();

  PracticeStore(this.file);

  Future<PracticeSettings?> load(String path) async {
    final song = (await file.read())[path];
    if (song is! Map<String, dynamic>) return null;
    try {
      return PracticeSettings.fromJson(song);
    } on Object {
      return null;
    }
  }

  // One at a time: each save rewrites the whole file from what it read.
  Future<void> save(String path, PracticeSettings settings) =>
      _saves = _saves.then((_) async {
        final all = await file.read();
        all[path] = settings.toJson();
        await file.write(all);
      });
}
