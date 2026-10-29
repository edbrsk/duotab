class TuningPreset {
  final String name;

  /// MIDI note numbers of the open strings, top string first.
  final List<int> tuning;

  const TuningPreset(this.name, this.tuning);
}

List<int> _down(List<int> tuning, int semitones) => [
  for (final note in tuning) note - semitones,
];

List<int> _drop(List<int> tuning) => [
  ...tuning.take(tuning.length - 1),
  tuning.last - 2,
];

const _e6 = [64, 59, 55, 50, 45, 40];
const _b7 = [64, 59, 55, 50, 45, 40, 35];
const _fSharp8 = [64, 59, 55, 50, 45, 40, 35, 30];

List<TuningPreset> tuningPresets(int strings) => switch (strings) {
  6 => [
    const TuningPreset('Standard E', _e6),
    TuningPreset('Standard E♭', _down(_e6, 1)),
    TuningPreset('Standard D', _down(_e6, 2)),
    TuningPreset('Standard C♯', _down(_e6, 3)),
    TuningPreset('Standard C', _down(_e6, 4)),
    TuningPreset('Standard B', _down(_e6, 5)),
    TuningPreset('Drop D', _drop(_e6)),
    TuningPreset('Drop C♯', _drop(_down(_e6, 1))),
    TuningPreset('Drop C', _drop(_down(_e6, 2))),
    TuningPreset('Drop B', _drop(_down(_e6, 3))),
  ],
  7 => [
    const TuningPreset('Standard B', _b7),
    TuningPreset('Standard A', _down(_b7, 2)),
    TuningPreset('Drop A', _drop(_b7)),
  ],
  8 => [
    const TuningPreset('Standard F♯', _fSharp8),
    TuningPreset('Standard E', _down(_fSharp8, 2)),
    TuningPreset('Drop E', _drop(_fSharp8)),
  ],
  _ => throw ArgumentError.value(strings, 'strings', 'must be 6, 7 or 8'),
};
