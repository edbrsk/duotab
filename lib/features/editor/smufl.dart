/// SMuFL code points in Bravura for the palette's symbols.
abstract final class Smufl {
  /// By alphaTab duration: 1 whole, 2 half … 64.
  static const notes = {
    1: '',
    2: '',
    4: '',
    8: '',
    16: '',
    32: '',
    64: '',
  };

  static const rests = {
    1: '',
    2: '',
    4: '',
    8: '',
    16: '',
    32: '',
    64: '',
  };

  static const augmentationDot = '';

  /// By tuplet: 3, 5, 6.
  static const tuplets = {3: '', 5: '', 6: ''};

  static const graceNote = '';

  static const doubleFlat = '';
  static const flat = '';
  static const natural = '';
  static const sharp = '';
  static const doubleSharp = '';

  /// By engine dynamic, quietest first.
  static const dynamics = {
    'ppp': '',
    'pp': '',
    'p': '',
    'mp': '',
    'mf': '',
    'f': '',
    'ff': '',
    'fff': '',
  };

  static const accent = '';
  static const marcato = '';
  static const staccato = '';
  static const tenuto = '';
  static const fermata = '';

  /// wiggleVibratoMediumFast, the segment alphaTab draws vibrato with.
  static const vibrato = '';
  static const deadNote = '';
  static const pickDown = '';
  static const pickUp = '';
  static const tremolo = '';
}
