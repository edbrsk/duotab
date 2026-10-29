import '../../engine/protocol.dart';
import 'tone.dart';

class TrackPractice {
  final bool mute;
  final bool solo;

  /// Null for tracks that are not guitar.
  final Tone? tone;

  const TrackPractice({this.mute = false, this.solo = false, this.tone});

  TrackPractice copyWith({bool? mute, bool? solo, Tone? tone}) => TrackPractice(
    mute: mute ?? this.mute,
    solo: solo ?? this.solo,
    tone: tone ?? this.tone,
  );

  Map<String, Object?> toJson() => {
    'mute': mute,
    'solo': solo,
    'tone': tone?.name,
  };

  factory TrackPractice.fromJson(Map<String, dynamic> json) => TrackPractice(
    mute: json['mute'] == true,
    solo: json['solo'] == true,
    tone: Tone.values.where((t) => t.name == json['tone']).firstOrNull,
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
