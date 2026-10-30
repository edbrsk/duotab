import 'dart:io';

import 'package:flutter/services.dart';

import '../../engine/engine_bridge.dart';
import '../../l10n/app_localizations.dart';

/// What the owner reads when an export fails, from the error behind it.
String exportFailureMessage(AppLocalizations l10n, Object error) =>
    switch (error) {
      PlatformException(code: 'pdf_failed') => l10n.exportFailedPdf,
      PlatformException(code: 'unavailable') => l10n.exportFailedBusy,
      EngineException(message: 'no guitar track') => l10n.exportFailedNoGuitar,
      PathNotFoundException() => l10n.exportFailedMissing,
      _ => l10n.exportFailedOther,
    };
