/// Turns pad digits into frets: a 1 or 2 followed quickly by another digit
/// makes a two-digit fret up to 24, as in Guitar Pro.
class FretEntry {
  static const maxFret = 24;

  final Duration window;
  final DateTime Function() now;
  int? _first;
  DateTime? _at;

  FretEntry({
    this.window = const Duration(milliseconds: 800),
    this.now = DateTime.now,
  });

  /// The fret to set for [digit].
  int digit(int digit) {
    final time = now();
    final first = _first;
    final quick = _at != null && time.difference(_at!) <= window;
    _at = time;
    if (first != null && quick && first * 10 + digit <= maxFret) {
      _first = null;
      return first * 10 + digit;
    }
    _first = digit == 1 || digit == 2 ? digit : null;
    return digit;
  }

  void reset() {
    _first = null;
    _at = null;
  }
}
