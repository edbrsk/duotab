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

  /// 0–16; null for the file's own level.
  final int? volume;

  const TrackPractice({
    this.mute = false,
    this.solo = false,
    this.tone,
    this.toneChosen = false,
    this.showNotation = true,
    this.showTab = true,
    this.volume,
  });

  TrackPractice copyWith({
    bool? mute,
    bool? solo,
    Tone? tone,
    bool? toneChosen,
    bool? showNotation,
    bool? showTab,
    int? volume,
  }) => TrackPractice(
    mute: mute ?? this.mute,
    solo: solo ?? this.solo,
    tone: tone ?? this.tone,
    toneChosen: toneChosen ?? this.toneChosen,
    showNotation: showNotation ?? this.showNotation,
    showTab: showTab ?? this.showTab,
    volume: volume ?? this.volume,
  );

  Map<String, Object?> toJson() => {
    'mute': mute,
    'solo': solo,
    'tone': tone?.name,
    'toneChosen': toneChosen,
    'showNotation': showNotation,
    'showTab': showTab,
    'volume': volume,
  };

  factory TrackPractice.fromJson(Map<String, dynamic> json) => TrackPractice(
    mute: json['mute'] == true,
    solo: json['solo'] == true,
    tone: Tone.values.where((t) => t.name == json['tone']).firstOrNull,
    // Tones saved before the choice was recorded may have been chosen.
    toneChosen: json['toneChosen'] as bool? ?? json['tone'] != null,
    showNotation: json['showNotation'] != false,
    showTab: json['showTab'] != false,
    volume: json['volume'] as int?,
  );
}

/// How the owner practises one song; kept by the app, never in the file.
class PracticeSettings {
  final double speed;
  final bool looping;
  final PlaybackRange? range;
  final Map<int, TrackPractice> tracks;

  const PracticeSettings({
    this.speed = 1.0,
    this.looping = false,
    this.range,
    this.tracks = const {},
  });

  PracticeSettings copyWith({
    double? speed,
    bool? looping,
    PlaybackRange? Function()? range,
    Map<int, TrackPractice>? tracks,
  }) => PracticeSettings(
    speed: speed ?? this.speed,
    looping: looping ?? this.looping,
    range: range != null ? range() : this.range,
    tracks: tracks ?? this.tracks,
  );

  Map<String, Object?> toJson() => {
    'speed': speed,
    'looping': looping,
    'range': range?.toJson(),
    'tracks': {
      for (final MapEntry(:key, :value) in tracks.entries)
        '$key': value.toJson(),
    },
  };

  factory PracticeSettings.fromJson(Map<String, dynamic> json) =>
      PracticeSettings(
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        looping: json['looping'] == true,
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
