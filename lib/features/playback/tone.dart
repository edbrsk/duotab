/// Guitar tones as 0-based General MIDI programs.
enum Tone {
  clean(27),
  overdrive(29),
  highGain(30);

  const Tone(this.program);

  final int program;

  static Tone? fromProgram(int program) =>
      values.where((t) => t.program == program).firstOrNull;
}
