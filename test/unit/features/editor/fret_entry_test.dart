import 'package:duotab/features/editor/fret_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late FretEntry entry;

  setUp(() {
    now = DateTime(2026);
    entry = FretEntry(now: () => now);
  });

  int after(int milliseconds, int digit) {
    now = now.add(Duration(milliseconds: milliseconds));
    return entry.digit(digit);
  }

  test('one digit is that fret', () {
    expect(entry.digit(7), 7);
  });

  test('two quick digits make a two-digit fret', () {
    expect(entry.digit(1), 1);
    expect(after(300, 2), 12);
  });

  test('a second digit past 24 starts a new fret', () {
    entry.digit(2);
    expect(after(100, 7), 7);
  });

  test('a digit after the window starts a new fret', () {
    entry.digit(1);
    expect(after(900, 5), 5);
  });

  test('a third quick digit starts again', () {
    entry.digit(1);
    after(100, 2);
    expect(after(100, 3), 3);
  });

  test('reset forgets the first digit', () {
    entry
      ..digit(1)
      ..reset();
    expect(after(100, 2), 2);
  });
}
