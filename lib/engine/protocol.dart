// Mirrors engine/src/protocol.ts: change both together.

enum TrackKind { guitar, drums, other }

class TrackSummary {
  final int index;
  final String name;
  final TrackKind kind;
  final int? stringCount;

  /// MIDI note numbers of the open strings, top string first.
  final List<int>? tuning;

  /// 0-based General MIDI program, as alphaTab stores it.
  final int midiProgram;

  const TrackSummary({
    required this.index,
    required this.name,
    required this.kind,
    required this.stringCount,
    required this.tuning,
    required this.midiProgram,
  });

  factory TrackSummary.fromJson(Map<String, dynamic> json) => TrackSummary(
    index: json['index'] as int,
    name: json['name'] as String,
    kind: TrackKind.values.byName(json['kind'] as String),
    stringCount: json['stringCount'] as int?,
    tuning: (json['tuning'] as List<dynamic>?)?.cast<int>(),
    midiProgram: json['midiProgram'] as int,
  );
}

class SongSummary {
  final String title;
  final List<TrackSummary> tracks;

  const SongSummary({required this.title, required this.tracks});

  factory SongSummary.fromJson(Map<String, dynamic> json) => SongSummary(
    title: json['title'] as String,
    tracks: [
      for (final t in json['tracks'] as List<dynamic>)
        TrackSummary.fromJson(t as Map<String, dynamic>),
    ],
  );

  List<TrackSummary> get guitarTracks =>
      tracks.where((t) => t.kind == TrackKind.guitar).toList();
}

class EngineEvent {
  /// `ready`, `rendered`, `error` or `playerState`.
  final String type;
  final Map<String, dynamic> payload;

  const EngineEvent(this.type, this.payload);
}
