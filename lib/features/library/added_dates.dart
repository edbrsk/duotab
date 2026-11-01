import '../../core/storage/json_file.dart';

/// When each song arrived, by path relative to Documents, so the library can
/// list the newest first. iOS keeps no such date: a copied-in file can carry
/// its old one, and every save moves it on.
class AddedDates {
  final JsonFile file;
  final DateTime Function() now;
  Future<void> _changes = Future.value();

  AddedDates(this.file, {this.now = DateTime.now});

  /// The date of each of [paths]. One not recorded yet arrived just now; on
  /// the first run, before any was recorded, each takes [fileDate] instead.
  Future<Map<String, DateTime>> datesFor(
    Iterable<String> paths,
    DateTime Function(String path) fileDate,
  ) async {
    late Map<String, DateTime> result;
    await _change((state) {
      var changed = !state.seeded;
      for (final path in paths) {
        if (state.dates.containsKey(path)) continue;
        state.dates[path] = state.seeded ? now() : fileDate(path);
        changed = true;
      }
      state.seeded = true;
      result = {for (final path in paths) path: state.dates[path]!};
      return changed;
    });
    return result;
  }

  /// Overwrites any date [to] was given meanwhile: a refresh can see the file
  /// at its new name before its date moves.
  Future<void> rename(String from, String to) => _change((state) {
    final date = state.dates.remove(from);
    if (date == null) return false;
    state.dates[to] = date;
    return true;
  });

  Future<void> forget(String path) =>
      _change((state) => state.dates.remove(path) != null);

  /// One at a time: each change rewrites the whole file from what it read.
  Future<void> _change(bool Function(_State state) change) {
    final done = _changes.then((_) async {
      final state = await _read();
      if (change(state)) await _write(state);
    });
    _changes = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }

  Future<_State> _read() async {
    final json = await file.read();
    final dates = json['dates'] as Map<String, dynamic>? ?? {};
    return _State(
      seeded: json['seeded'] == true,
      dates: {
        for (final MapEntry(:key, :value) in dates.entries)
          key: ?DateTime.tryParse('$value'),
      },
    );
  }

  Future<void> _write(_State state) => file.write({
    'seeded': state.seeded,
    'dates': {
      for (final MapEntry(:key, :value) in state.dates.entries)
        key: value.toIso8601String(),
    },
  });
}

class _State {
  bool seeded;
  final Map<String, DateTime> dates;

  _State({required this.seeded, required this.dates});
}
