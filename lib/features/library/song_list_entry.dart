import 'package:path/path.dart' as p;

class SongListEntry {
  /// Relative to the app's Documents folder.
  final String path;

  /// The file name without its extension, as the Files app shows it.
  final String name;
  final String? tuningLabel;
  final int? stringCount;
  final bool readable;

  /// For an edited copy, the opened file it was made from, which the library
  /// lists through this entry.
  final String? original;

  const SongListEntry({
    required this.path,
    required this.name,
    required this.tuningLabel,
    required this.stringCount,
    required this.readable,
    this.original,
  });

  SongListEntry standingFor(String original, {required bool named}) =>
      SongListEntry(
        path: path,
        name: named ? p.basenameWithoutExtension(original) : name,
        tuningLabel: tuningLabel,
        stringCount: stringCount,
        readable: readable,
        original: original,
      );
}

const _flatNames = [
  'C',
  'D♭',
  'D',
  'E♭',
  'E',
  'F',
  'G♭',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
];

/// Open strings low to high, from MIDI notes listed top string first.
String tuningLabel(List<int> topStringFirst) =>
    topStringFirst.reversed.map((note) => _flatNames[note % 12]).join(' ');
