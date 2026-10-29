import 'package:duotab/features/settings/licences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bundle extends CachingAssetBundle {
  static const texts = {
    'assets/engine/alphatab/LICENSE': 'MPL TEXT',
    'assets/engine/alphatab/font/Bravura-OFL.txt': 'OFL TEXT',
    'assets/engine/alphatab/soundfont/LICENSE': 'APACHE TEXT',
  };

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(texts[key]!.codeUnits));
}

void main() {
  test('registers alphaTab, Bravura and Sonivox', () async {
    LicenseRegistry.reset();
    registerBundledLicences(_Bundle());
    final licences = await LicenseRegistry.licenses.toList();

    expect(licences.expand((l) => l.packages), [
      'alphaTab',
      'Bravura',
      'Sonivox SoundFont',
    ]);
    final alphaTab = licences.first.paragraphs.map((p) => p.text).join('\n');
    expect(alphaTab, contains('https://github.com/CoderLine/alphaTab'));
    expect(alphaTab, contains('MPL TEXT'));
  });
}
