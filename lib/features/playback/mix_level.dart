import 'dart:math' as math;

/// A mixer level in dB; −∞ is [double.negativeInfinity].
const minDb = -40.0;
const maxDb = 10.0;

/// The fader's share at its left end that is −∞, as on Guitar Pro's.
const _silentStretch = 0.02;

double faderPosition(double db) {
  if (db == double.negativeInfinity) return 0;
  final share = (db.clamp(minDb, maxDb) - minDb) / (maxDb - minDb);
  return _silentStretch + (1 - _silentStretch) * share;
}

double dbAtPosition(double position) {
  if (position < _silentStretch) return double.negativeInfinity;
  final share = (position - _silentStretch) / (1 - _silentStretch);
  return snapDb(minDb + (maxDb - minDb) * share);
}

/// The nearest half decibel; a tie goes toward 0 dB, so Guitar Pro's default
/// (−0.25 dB) reads 0.0 dB, as Guitar Pro shows it.
double snapDb(double db) {
  if (!db.isFinite) return db;
  final halves = db * 2;
  final tie = (halves.abs() - halves.abs().floorToDouble()) == 0.5;
  return (tie ? halves.truncate() : halves.round()) / 2 + 0.0;
}

String dbLabel(double db) {
  if (db == double.negativeInfinity) return '−∞ dB';
  final sign = db > 0 ? '+' : (db < 0 ? '−' : '');
  return '$sign${db.abs().toStringAsFixed(1)} dB';
}

String panLabel(double pan) {
  final amount = (pan.abs() * 50).round();
  if (amount == 0) return 'C';
  return '${pan < 0 ? 'L' : 'R'}$amount';
}

/// A 0–16 practice volume as the dB that sounds the same. It played as MIDI
/// volume `8 × volume`, which the synth cubes, and 0 dB plays as 96.
double dbFromLegacyVolume(int volume) {
  if (volume <= 0) return double.negativeInfinity;
  return snapDb(60 * math.log(volume / 12) / math.ln10);
}
