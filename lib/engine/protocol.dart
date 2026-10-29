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

  /// Per bar; filled when the song is opened, empty in library summaries.
  final List<bool> barsWithNotes;

  const TrackSummary({
    required this.index,
    required this.name,
    required this.kind,
    required this.stringCount,
    required this.tuning,
    required this.midiProgram,
    this.barsWithNotes = const [],
  });

  factory TrackSummary.fromJson(Map<String, dynamic> json) => TrackSummary(
    index: json['index'] as int,
    name: json['name'] as String,
    kind: TrackKind.values.byName(json['kind'] as String),
    stringCount: json['stringCount'] as int?,
    tuning: (json['tuning'] as List<dynamic>?)?.cast<int>(),
    midiProgram: json['midiProgram'] as int,
    barsWithNotes:
        (json['barsWithNotes'] as List<dynamic>?)?.cast<bool>() ?? const [],
  );
}

class Section {
  final String marker;
  final String text;

  const Section({required this.marker, required this.text});

  factory Section.fromJson(Map<String, dynamic> json) =>
      Section(marker: json['marker'] as String, text: json['text'] as String);
}

/// Where the bar first plays, counting repeats.
class BarInfo {
  final int index;
  final int startTick;
  final int startMs;
  final double tempo;
  final Section? section;

  const BarInfo({
    required this.index,
    required this.startTick,
    required this.startMs,
    required this.tempo,
    this.section,
  });

  factory BarInfo.fromJson(Map<String, dynamic> json) => BarInfo(
    index: json['index'] as int,
    startTick: json['startTick'] as int,
    startMs: json['startMs'] as int,
    tempo: (json['tempo'] as num).toDouble(),
    section: switch (json['section']) {
      final Map<String, dynamic> section => Section.fromJson(section),
      _ => null,
    },
  );
}

class SongSummary {
  final String title;
  final List<TrackSummary> tracks;

  /// Filled when the song is opened, empty in library summaries.
  final List<BarInfo> bars;

  const SongSummary({
    required this.title,
    required this.tracks,
    this.bars = const [],
  });

  factory SongSummary.fromJson(Map<String, dynamic> json) => SongSummary(
    title: json['title'] as String,
    tracks: [
      for (final t in json['tracks'] as List<dynamic>)
        TrackSummary.fromJson(t as Map<String, dynamic>),
    ],
    bars: [
      for (final b in (json['bars'] as List<dynamic>?) ?? const [])
        BarInfo.fromJson(b as Map<String, dynamic>),
    ],
  );

  List<TrackSummary> get guitarTracks =>
      tracks.where((t) => t.kind == TrackKind.guitar).toList();
}

/// An A–B loop, in MIDI ticks.
class PlaybackRange {
  final int startTick;
  final int endTick;

  const PlaybackRange({required this.startTick, required this.endTick});

  factory PlaybackRange.fromJson(Map<String, dynamic> json) => PlaybackRange(
    startTick: (json['startTick'] as num).toInt(),
    endTick: (json['endTick'] as num).toInt(),
  );

  Map<String, Object> toJson() => {'startTick': startTick, 'endTick': endTick};
}

class TrackMix {
  final int index;
  final bool mute;
  final bool solo;

  /// 0-based General MIDI program.
  final int program;

  const TrackMix({
    required this.index,
    required this.mute,
    required this.solo,
    required this.program,
  });

  Map<String, Object> toJson() => {
    'index': index,
    'mute': mute,
    'solo': solo,
    'program': program,
  };
}

class EngineEvent {
  /// `ready`, `rendered`, `error`, `playerState` or `position`.
  final String type;
  final Map<String, dynamic> payload;

  const EngineEvent(this.type, this.payload);
}
