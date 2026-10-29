import 'package:duotab/features/editor/tuning_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('6 strings start with Standard E and include Drop D', () {
    final presets = tuningPresets(6);
    expect(presets.first.name, 'Standard E');
    expect(presets.first.tuning, [64, 59, 55, 50, 45, 40]);
    expect(presets.firstWhere((t) => t.name == 'Drop D').tuning, [
      64,
      59,
      55,
      50,
      45,
      38,
    ]);
  });

  test('7 strings include Standard B', () {
    expect(tuningPresets(7).firstWhere((t) => t.name == 'Standard B').tuning, [
      64,
      59,
      55,
      50,
      45,
      40,
      35,
    ]);
  });

  test('8 strings include Standard F♯', () {
    expect(tuningPresets(8).firstWhere((t) => t.name == 'Standard F♯').tuning, [
      64,
      59,
      55,
      50,
      45,
      40,
      35,
      30,
    ]);
  });

  test('every preset has as many notes as strings', () {
    for (final strings in [6, 7, 8]) {
      for (final preset in tuningPresets(strings)) {
        expect(preset.tuning, hasLength(strings), reason: preset.name);
      }
    }
  });

  test('the spec minimum is there', () {
    expect(
      tuningPresets(6).map((t) => t.name),
      containsAll([
        'Standard E',
        'Standard E♭',
        'Standard D',
        'Standard C♯',
        'Standard C',
        'Standard B',
      ]),
    );
    expect(
      tuningPresets(7).map((t) => t.name),
      containsAll(['Standard B', 'Standard A']),
    );
    expect(
      tuningPresets(8).map((t) => t.name),
      containsAll(['Standard F♯', 'Standard E']),
    );
  });
}
