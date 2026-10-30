import 'dart:math' as math;

/// dBFS, left and right.
class MeterLevel {
  final double left;
  final double right;

  const MeterLevel(this.left, this.right);
}

/// What the engine measured as the song played; a null meter is silent.
class Levels {
  final List<MeterLevel?> tracks;
  final MeterLevel? master;

  const Levels({required this.tracks, this.master});

  factory Levels.fromJson(Map<String, dynamic> json) => Levels(
    tracks: [
      for (final t in (json['tracks'] as List<dynamic>?) ?? const []) _level(t),
    ],
    master: _level(json['master']),
  );
}

MeterLevel? _level(Object? json) => switch (json) {
  [final num left, final num right] => MeterLevel(
    left.toDouble(),
    right.toDouble(),
  ),
  _ => null,
};

const meterFallDbPerSecond = 20.0;

/// Where a meter showing [shown] [since] ago stands once [incoming] arrives.
double meterShown({
  required double shown,
  required Duration since,
  required double incoming,
}) {
  final fallen =
      shown -
      meterFallDbPerSecond *
          since.inMicroseconds /
          Duration.microsecondsPerSecond;
  return math.max(incoming, fallen);
}
