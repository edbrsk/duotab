import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DuoTab'**
  String get appTitle;

  /// No description provided for @foldedMessage.
  ///
  /// In en, this message translates to:
  /// **'Open your iPhone Duo to continue'**
  String get foldedMessage;

  /// No description provided for @tabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// No description provided for @tabEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get tabEditor;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @navigationLabel.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get navigationLabel;

  /// No description provided for @widerToEdit.
  ///
  /// In en, this message translates to:
  /// **'Make DuoTab wider to edit'**
  String get widerToEdit;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add Guitar Pro or MusicXML files in the Files app, under On My iPhone › DuoTab'**
  String get libraryEmpty;

  /// No description provided for @unreadableFile.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open this file'**
  String get unreadableFile;

  /// No description provided for @newSong.
  ///
  /// In en, this message translates to:
  /// **'New song'**
  String get newSong;

  /// No description provided for @stringsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} strings'**
  String stringsCount(int count);

  /// No description provided for @noGuitarTrack.
  ///
  /// In en, this message translates to:
  /// **'This song has no guitar track'**
  String get noGuitarTrack;

  /// No description provided for @noSongOpen.
  ///
  /// In en, this message translates to:
  /// **'Open a song from the library'**
  String get noSongOpen;

  /// No description provided for @tracksHeading.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracksHeading;

  /// No description provided for @scoreError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t show this song: {message}'**
  String scoreError(String message);

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @loop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get loop;

  /// No description provided for @tempoMarking.
  ///
  /// In en, this message translates to:
  /// **'♩ = {bpm}'**
  String tempoMarking(int bpm);

  /// No description provided for @countIn.
  ///
  /// In en, this message translates to:
  /// **'Count-in'**
  String get countIn;

  /// No description provided for @metronome.
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get metronome;

  /// No description provided for @defaultTone.
  ///
  /// In en, this message translates to:
  /// **'Default tone'**
  String get defaultTone;

  /// No description provided for @toneClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get toneClean;

  /// No description provided for @toneOverdrive.
  ///
  /// In en, this message translates to:
  /// **'Overdrive'**
  String get toneOverdrive;

  /// No description provided for @toneHighGain.
  ///
  /// In en, this message translates to:
  /// **'High gain'**
  String get toneHighGain;

  /// No description provided for @licences.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get licences;

  /// No description provided for @muteTrack.
  ///
  /// In en, this message translates to:
  /// **'Mute {name}'**
  String muteTrack(String name);

  /// No description provided for @soloTrack.
  ///
  /// In en, this message translates to:
  /// **'Solo {name}'**
  String soloTrack(String name);

  /// No description provided for @showTracks.
  ///
  /// In en, this message translates to:
  /// **'Show tracks'**
  String get showTracks;

  /// No description provided for @hideTracks.
  ///
  /// In en, this message translates to:
  /// **'Hide tracks'**
  String get hideTracks;

  /// No description provided for @trackHeading.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get trackHeading;

  /// No description provided for @tuning.
  ///
  /// In en, this message translates to:
  /// **'Tuning'**
  String get tuning;

  /// No description provided for @tone.
  ///
  /// In en, this message translates to:
  /// **'Tone'**
  String get tone;

  /// No description provided for @hideTrackPanel.
  ///
  /// In en, this message translates to:
  /// **'Hide track panel'**
  String get hideTrackPanel;

  /// No description provided for @showTrackPanel.
  ///
  /// In en, this message translates to:
  /// **'Show track panel'**
  String get showTrackPanel;

  /// No description provided for @notation.
  ///
  /// In en, this message translates to:
  /// **'Notation'**
  String get notation;

  /// No description provided for @standardNotation.
  ///
  /// In en, this message translates to:
  /// **'Standard notation'**
  String get standardNotation;

  /// No description provided for @tab.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get tab;

  /// No description provided for @fret.
  ///
  /// In en, this message translates to:
  /// **'Fret'**
  String get fret;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// No description provided for @previousBeat.
  ///
  /// In en, this message translates to:
  /// **'Previous beat'**
  String get previousBeat;

  /// No description provided for @nextBeat.
  ///
  /// In en, this message translates to:
  /// **'Next beat'**
  String get nextBeat;

  /// No description provided for @stringUp.
  ///
  /// In en, this message translates to:
  /// **'String up'**
  String get stringUp;

  /// No description provided for @stringDown.
  ///
  /// In en, this message translates to:
  /// **'String down'**
  String get stringDown;

  /// No description provided for @hidePalette.
  ///
  /// In en, this message translates to:
  /// **'Hide palette'**
  String get hidePalette;

  /// No description provided for @showPalette.
  ///
  /// In en, this message translates to:
  /// **'Show palette'**
  String get showPalette;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @noteValue.
  ///
  /// In en, this message translates to:
  /// **'Note value'**
  String get noteValue;

  /// No description provided for @rests.
  ///
  /// In en, this message translates to:
  /// **'Rests'**
  String get rests;

  /// No description provided for @dots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get dots;

  /// No description provided for @voiceN.
  ///
  /// In en, this message translates to:
  /// **'Voice {number}'**
  String voiceN(int number);

  /// No description provided for @wholeNote.
  ///
  /// In en, this message translates to:
  /// **'Whole note'**
  String get wholeNote;

  /// No description provided for @halfNote.
  ///
  /// In en, this message translates to:
  /// **'Half note'**
  String get halfNote;

  /// No description provided for @quarterNote.
  ///
  /// In en, this message translates to:
  /// **'Quarter note'**
  String get quarterNote;

  /// No description provided for @eighthNote.
  ///
  /// In en, this message translates to:
  /// **'Eighth note'**
  String get eighthNote;

  /// No description provided for @sixteenthNote.
  ///
  /// In en, this message translates to:
  /// **'Sixteenth note'**
  String get sixteenthNote;

  /// No description provided for @thirtySecondNote.
  ///
  /// In en, this message translates to:
  /// **'Thirty-second note'**
  String get thirtySecondNote;

  /// No description provided for @sixtyFourthNote.
  ///
  /// In en, this message translates to:
  /// **'Sixty-fourth note'**
  String get sixtyFourthNote;

  /// No description provided for @wholeRest.
  ///
  /// In en, this message translates to:
  /// **'Whole rest'**
  String get wholeRest;

  /// No description provided for @halfRest.
  ///
  /// In en, this message translates to:
  /// **'Half rest'**
  String get halfRest;

  /// No description provided for @quarterRest.
  ///
  /// In en, this message translates to:
  /// **'Quarter rest'**
  String get quarterRest;

  /// No description provided for @eighthRest.
  ///
  /// In en, this message translates to:
  /// **'Eighth rest'**
  String get eighthRest;

  /// No description provided for @sixteenthRest.
  ///
  /// In en, this message translates to:
  /// **'Sixteenth rest'**
  String get sixteenthRest;

  /// No description provided for @thirtySecondRest.
  ///
  /// In en, this message translates to:
  /// **'Thirty-second rest'**
  String get thirtySecondRest;

  /// No description provided for @sixtyFourthRest.
  ///
  /// In en, this message translates to:
  /// **'Sixty-fourth rest'**
  String get sixtyFourthRest;

  /// No description provided for @dot.
  ///
  /// In en, this message translates to:
  /// **'Dot'**
  String get dot;

  /// No description provided for @doubleDot.
  ///
  /// In en, this message translates to:
  /// **'Double dot'**
  String get doubleDot;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
