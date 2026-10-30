import 'package:duoscore/features/playback/levels.dart';
import 'package:duoscore/features/playback/mix_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const off = double.negativeInfinity;

  test('the fader puts 0 dB at four fifths, like Guitar Pro', () {
    expect(faderPosition(0), closeTo(0.804, 0.001));
    expect(faderPosition(10), 1);
    expect(faderPosition(off), 0);
  });

  test('the left end of the fader is −∞', () {
    expect(dbAtPosition(0.01), off);
    expect(dbAtPosition(0.804), 0);
    expect(dbAtPosition(1), 10);
  });

  test('levels snap to half decibels, ties toward 0 dB', () {
    expect(snapDb(-0.25), 0);
    expect(snapDb(-0.26), -0.5);
    expect(snapDb(6.2), 6);
    expect(snapDb(off), off);
  });

  test('labels', () {
    expect(dbLabel(0), '0.0 dB');
    expect(dbLabel(6), '+6.0 dB');
    expect(dbLabel(-6), '−6.0 dB');
    expect(dbLabel(off), '−∞ dB');
    expect(panLabel(0), 'C');
    expect(panLabel(-1), 'L50');
    expect(panLabel(0.5), 'R25');
  });

  test('a legacy volume converts to the dB that sounds the same', () {
    // It played as MIDI volume 8 × volume; 0 dB plays as MIDI volume 96.
    expect(dbFromLegacyVolume(12), 0);
    expect(dbFromLegacyVolume(6), -18);
    expect(dbFromLegacyVolume(15), 6);
    expect(dbFromLegacyVolume(0), off);
  });

  test('a meter rises at once and falls 20 dB a second', () {
    expect(meterShown(shown: -30, since: Duration.zero, incoming: -6), -6);
    expect(
      meterShown(
        shown: -6,
        since: const Duration(milliseconds: 500),
        incoming: off,
      ),
      -16,
    );
    expect(
      meterShown(
        shown: -10,
        since: const Duration(milliseconds: 100),
        incoming: -11,
      ),
      -11,
    );
  });
}
