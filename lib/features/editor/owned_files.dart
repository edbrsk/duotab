import '../../core/storage/json_file.dart';

/// Songs the app created or copied, by path relative to Documents: the only
/// files it ever overwrites. A copy also remembers the file it was made from.
class OwnedFiles {
  final JsonFile file;

  OwnedFiles(this.file);

  Future<bool> owns(String path) async => (await _paths()).contains(path);

  Future<Set<String>> all() => _paths();

  /// Each edited copy and the opened file it was made from.
  Future<Map<String, String>> originals() async => (await _read()).originals;

  /// Copies made before the app recorded their original were paired by name,
  /// once; from then on only records pair.
  Future<bool> pairedByName() async =>
      (await file.read())['pairedByName'] == true;

  Future<void> markPairedByName() async {
    final state = await _read();
    await _write(state, pairedByName: true);
  }

  Future<void> add(String path) async {
    final state = await _read();
    if (state.paths.add(path)) await _write(state);
  }

  Future<void> addCopy(String copy, {required String of}) async {
    final state = await _read();
    state.paths.add(copy);
    state.originals[copy] = of;
    await _write(state);
  }

  /// Forgets [path], and any copy record it is part of.
  Future<void> remove(String path) async {
    final state = await _read();
    final removed = state.paths.remove(path);
    final before = state.originals.length;
    state.originals.removeWhere(
      (copy, original) => copy == path || original == path,
    );
    if (removed || state.originals.length != before) await _write(state);
  }

  Future<void> rename(String from, String to) async {
    final state = await _read();
    var changed = false;
    if (state.paths.remove(from)) {
      state.paths.add(to);
      changed = true;
    }
    if (state.originals.remove(from) case final original?) {
      state.originals[to] = original;
      changed = true;
    }
    for (final copy in state.originals.keys.toList()) {
      if (state.originals[copy] == from) {
        state.originals[copy] = to;
        changed = true;
      }
    }
    if (changed) await _write(state);
  }

  Future<Set<String>> _paths() async => (await _read()).paths;

  Future<({Set<String> paths, Map<String, String> originals})> _read() async {
    final json = await file.read();
    return (
      paths: {...(json['paths'] as List<dynamic>? ?? []).whereType<String>()},
      originals: {
        for (final MapEntry(:key, :value)
            in ((json['originals'] as Map<String, dynamic>?) ?? {}).entries)
          if (value is String) key: value,
      },
    );
  }

  Future<void> _write(
    ({Set<String> paths, Map<String, String> originals}) state, {
    bool? pairedByName,
  }) async => file.write({
    'paths': state.paths.toList(),
    'originals': state.originals,
    'pairedByName': pairedByName ?? await this.pairedByName(),
  });
}
