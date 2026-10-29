// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DuoTab';

  @override
  String get foldedMessage => 'Open your iPhone Duo to continue';

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabEditor => 'Editor';

  @override
  String get tabSettings => 'Settings';

  @override
  String get navigationLabel => 'Main navigation';

  @override
  String get widerToEdit => 'Make DuoTab wider to edit';
}
