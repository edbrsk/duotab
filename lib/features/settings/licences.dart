import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The engine's bundled code and assets, whose licences the app must show.
void registerBundledLicences(AssetBundle bundle) {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['alphaTab'],
      'Shipped unmodified. Source: https://github.com/CoderLine/alphaTab\n\n'
      '${await bundle.loadString('assets/engine/alphatab/LICENSE')}',
    );
    yield LicenseEntryWithLineBreaks(const [
      'Bravura',
    ], await bundle.loadString('assets/engine/alphatab/font/Bravura-OFL.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Sonivox SoundFont',
    ], await bundle.loadString('assets/engine/alphatab/soundfont/LICENSE'));
  });
}
