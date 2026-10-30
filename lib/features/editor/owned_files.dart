import '../../core/storage/json_file.dart';

/// Songs the app created or copied, by path relative to Documents: the only
/// files it ever overwrites. A copy also remembers the file it was made from.
class OwnedFiles {
  final JsonFile file;
  Future<void> _changes = Future.value();

  OwnedFiles(this.file);

  /// One at a time: each change rewrites the whole file from what it read.
  /// A failed change fails only its own caller.
  Future<void> _change(
    bool Function(({Set<String> paths, Map<String, String> originals}) state)
    change,
  ) {
    final done = _changes.then((_) async {
      final state = await _read();
      if (change(state)) await _write(state);
    });
    _changes = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }

  Future<bool> owns(String path) async => (await _paths()).contains(path);

  Future<Set<String>> all() => _paths();

  /// Each edited copy and the opened file it was made from.
  Future<Map<String, String>> originals() async => (await _read()).originals;

  /// Copies made before the app recorded their original were paired by name,
  /// once; from then on only records pair.
  Future<bool> pairedByName() async =>
      (await file.read())['pairedByName'] == true;

  Future<void> markPairedByName() async {
    await _changes;
    final state = await _read();
    await _write(state, pairedByName: true);
  }

  Future<void> add(String path) => _change((state) => state.paths.add(path));

  Future<void> addCopy(String copy, {required String of}) => _change((state) {
    state.paths.add(copy);
    state.originals[copy] = of;
    return true;
  });

  /// Forgets [path], and any copy record it is part of.
  Future<void> remove(String path) => _change((state) {
    final removed = state.paths.remove(path);
    final before = state.originals.length;
    state.originals.removeWhere(
      (copy, original) => copy == path || original == path,
    );
    return removed || state.originals.length != before;
  });

  /// Forgets files deleted outside the app, so another file that arrives
  /// under one of their names is never overwritten as the app's own.
  Future<void> forgetMissing(bool Function(String path) exists) => _change((
    state,
  ) {
    final paths = state.paths.length;
    final originals = state.originals.length;
    state.paths.removeWhere((path) => !exists(path));
    state.originals.removeWhere(
      (copy, original) => !exists(copy) || !exists(original),
    );
    return state.paths.length != paths || state.originals.length != originals;
  });

  Future<void> rename(String from, String to) => _change((state) {
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
    return changed;
  });

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
