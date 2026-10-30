import '../../engine/protocol.dart';
import 'tone.dart';

class TrackPractice {
  final bool mute;
  final bool solo;

  /// Null for tracks that are not guitar.
  final Tone? tone;

  /// The owner chose [tone]; otherwise it is worked out again on each open,
  /// from the file or the default tone.
  final bool toneChosen;
  final bool showNotation;
  final bool showTab;

  /// Null for the file's own level; −∞ is [double.negativeInfinity].
  final double? volumeDb;

  /// −1…1; null for the file's own pan.
  final double? pan;

  /// A 0–16 volume saved before levels were in dB; resolving converts it.
  final int? legacyVolume;

  const TrackPractice({
    this.mute = false,
    this.solo = false,
    this.tone,
    this.toneChosen = false,
    this.showNotation = true,
    this.showTab = true,
    this.volumeDb,
    this.pan,
    this.legacyVolume,
  });

  TrackPractice copyWith({
    bool? mute,
    bool? solo,
    Tone? tone,
    bool? toneChosen,
    bool? showNotation,
    bool? showTab,
    double? volumeDb,
    double? pan,
  }) => TrackPractice(
    mute: mute ?? this.mute,
    solo: solo ?? this.solo,
    tone: tone ?? this.tone,
    toneChosen: toneChosen ?? this.toneChosen,
    showNotation: showNotation ?? this.showNotation,
    showTab: showTab ?? this.showTab,
    volumeDb: volumeDb ?? this.volumeDb,
    pan: pan ?? this.pan,
    legacyVolume: legacyVolume,
  );

  Map<String, Object?> toJson() => {
    'mute': mute,
    'solo': solo,
    'tone': tone?.name,
    'toneChosen': toneChosen,
    'showNotation': showNotation,
    'showTab': showTab,
    'volumeDb': _dbToJson(volumeDb),
    'pan': pan,
  };

  factory TrackPractice.fromJson(Map<String, dynamic> json) => TrackPractice(
    mute: json['mute'] == true,
    solo: json['solo'] == true,
    tone: Tone.values.where((t) => t.name == json['tone']).firstOrNull,
    // Tones saved before the choice was recorded may have been chosen.
    toneChosen: json['toneChosen'] as bool? ?? json['tone'] != null,
    showNotation: json['showNotation'] != false,
    showTab: json['showTab'] != false,
    volumeDb: _dbFromJson(json['volumeDb']),
    pan: (json['pan'] as num?)?.toDouble(),
    legacyVolume: json['volume'] as int?,
  );
}

/// How the owner practises one song; kept by the app, never in the file.
class PracticeSettings {
  final double speed;
  final bool looping;
  final PlaybackRange? range;
  final Map<int, TrackPractice> tracks;

  /// Null for the file's own master level.
  final double? masterDb;

  const PracticeSettings({
    this.speed = 1.0,
    this.looping = false,
    this.range,
    this.tracks = const {},
    this.masterDb,
  });

  PracticeSettings copyWith({
    double? speed,
    bool? looping,
    PlaybackRange? Function()? range,
    Map<int, TrackPractice>? tracks,
    double? masterDb,
  }) => PracticeSettings(
    speed: speed ?? this.speed,
    looping: looping ?? this.looping,
    range: range != null ? range() : this.range,
    tracks: tracks ?? this.tracks,
    masterDb: masterDb ?? this.masterDb,
  );

  Map<String, Object?> toJson() => {
    'speed': speed,
    'looping': looping,
    'range': range?.toJson(),
    'tracks': {
      for (final MapEntry(:key, :value) in tracks.entries)
        '$key': value.toJson(),
    },
    'masterDb': _dbToJson(masterDb),
  };

  factory PracticeSettings.fromJson(Map<String, dynamic> json) =>
      PracticeSettings(
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        looping: json['looping'] == true,
        masterDb: _dbFromJson(json['masterDb']),
        range: switch (json['range']) {
          final Map<String, dynamic> range => PlaybackRange.fromJson(range),
          _ => null,
        },
        tracks: {
          for (final MapEntry(:key, :value)
              in ((json['tracks'] as Map<String, dynamic>?) ?? {}).entries)
            ?int.tryParse(key): TrackPractice.fromJson(
              value as Map<String, dynamic>,
            ),
        },
      );
}

/// JSON has no −∞, so it is kept as `"-inf"`.
Object? _dbToJson(double? db) => switch (db) {
  final db? when !db.isFinite => '-inf',
  final db => db,
};

double? _dbFromJson(Object? json) => switch (json) {
  '-inf' => double.negativeInfinity,
  final num db => db.toDouble(),
  _ => null,
};
