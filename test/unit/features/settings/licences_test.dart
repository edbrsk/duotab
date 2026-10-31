import 'package:duoscore/features/settings/licences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bundle extends CachingAssetBundle {
  static const texts = {
    'assets/engine/alphatab/LICENSE': 'MPL TEXT',
    'assets/engine/alphatab/font/Bravura-OFL.txt': 'OFL TEXT',
    'assets/engine/soundfont/LICENSE.txt': 'GENERALUSER TEXT',
  };

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(texts[key]!.codeUnits));
}

void main() {
  test('registers alphaTab, Bravura and GeneralUser GS', () async {
    LicenseRegistry.reset();
    registerBundledLicences(_Bundle());
    final licences = await LicenseRegistry.licenses.toList();

    expect(licences.expand((l) => l.packages), [
      'alphaTab',
      'Bravura',
      'GeneralUser GS',
    ]);
    final alphaTab = licences.first.paragraphs.map((p) => p.text).join('\n');
    expect(alphaTab, contains('https://github.com/CoderLine/alphaTab'));
    expect(alphaTab, contains('MPL TEXT'));
    expect(alphaTab, contains('Thank you to CoderLine'));
    expect(alphaTab, contains('"rendered by alphaTab"'));
    expect(
      licences.last.paragraphs.map((p) => p.text).join('\n'),
      contains('GENERALUSER TEXT'),
    );
  });
}
