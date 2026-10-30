import 'dart:io';

import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/features/export/export_failure.dart';
import 'package:duoscore/l10n/app_localizations_en.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('export errors read as messages', () {
    expect(
      exportFailureMessage(l10n, PlatformException(code: 'pdf_failed')),
      "Couldn't make the PDF",
    );
    expect(
      exportFailureMessage(l10n, PlatformException(code: 'unavailable')),
      'Another export is open',
    );
    expect(
      exportFailureMessage(l10n, const EngineException('no guitar track')),
      'This song has no guitar track to print',
    );
    expect(
      exportFailureMessage(
        l10n,
        const PathNotFoundException('a.gp', OSError()),
      ),
      'The song file is missing',
    );
    expect(exportFailureMessage(l10n, Exception('x')), "Couldn't export");
  });
}
