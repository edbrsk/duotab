import 'package:duoscore/features/library/library_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches part of a title, whatever the case', () {
    expect(matchesSearch('07 Collateral Damage', 'collat'), isTrue);
    expect(matchesSearch('07 Collateral Damage', 'DAMAGE'), isTrue);
    expect(matchesSearch('07 Collateral Damage', 'riff'), isFalse);
  });

  test('accents on either side do not matter', () {
    expect(matchesSearch('Étude n°120', 'etude'), isTrue);
    expect(matchesSearch('Etude n°120', 'étude'), isTrue);
    expect(matchesSearch('Canción', 'cancion'), isTrue);
  });

  test('a blank search matches every title', () {
    expect(matchesSearch('Riff', '   '), isTrue);
  });

  test('spaces around the search are ignored', () {
    expect(matchesSearch('Of Our Time', ' our '), isTrue);
  });
}
