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
  /// **'DuoScore'**
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
  /// **'Make DuoScore wider to edit'**
  String get widerToEdit;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap Import to add Guitar Pro or MusicXML files'**
  String get libraryEmpty;

  /// No description provided for @importSongs.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importSongs;

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

  /// No description provided for @triplet.
  ///
  /// In en, this message translates to:
  /// **'Triplet'**
  String get triplet;

  /// No description provided for @quintuplet.
  ///
  /// In en, this message translates to:
  /// **'Quintuplet'**
  String get quintuplet;

  /// No description provided for @sextuplet.
  ///
  /// In en, this message translates to:
  /// **'Sextuplet'**
  String get sextuplet;

  /// No description provided for @tie.
  ///
  /// In en, this message translates to:
  /// **'Tie'**
  String get tie;

  /// No description provided for @graceNote.
  ///
  /// In en, this message translates to:
  /// **'Grace note'**
  String get graceNote;

  /// No description provided for @bar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get bar;

  /// No description provided for @bars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get bars;

  /// No description provided for @clef.
  ///
  /// In en, this message translates to:
  /// **'Clef'**
  String get clef;

  /// No description provided for @trebleClef.
  ///
  /// In en, this message translates to:
  /// **'Treble clef'**
  String get trebleClef;

  /// No description provided for @bassClef.
  ///
  /// In en, this message translates to:
  /// **'Bass clef'**
  String get bassClef;

  /// No description provided for @keySignature.
  ///
  /// In en, this message translates to:
  /// **'Key signature'**
  String get keySignature;

  /// No description provided for @major.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get major;

  /// No description provided for @minor.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get minor;

  /// No description provided for @moreBeats.
  ///
  /// In en, this message translates to:
  /// **'More beats'**
  String get moreBeats;

  /// No description provided for @fewerBeats.
  ///
  /// In en, this message translates to:
  /// **'Fewer beats'**
  String get fewerBeats;

  /// No description provided for @beatValue.
  ///
  /// In en, this message translates to:
  /// **'Beat value {value}'**
  String beatValue(int value);

  /// No description provided for @tempoChange.
  ///
  /// In en, this message translates to:
  /// **'Tempo marking'**
  String get tempoChange;

  /// No description provided for @setTempo.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setTempo;

  /// No description provided for @removeTempoChange.
  ///
  /// In en, this message translates to:
  /// **'Remove tempo change'**
  String get removeTempoChange;

  /// No description provided for @insertBar.
  ///
  /// In en, this message translates to:
  /// **'Insert bar'**
  String get insertBar;

  /// No description provided for @deleteBar.
  ///
  /// In en, this message translates to:
  /// **'Delete bar'**
  String get deleteBar;

  /// No description provided for @copyBars.
  ///
  /// In en, this message translates to:
  /// **'Copy bars'**
  String get copyBars;

  /// No description provided for @pasteBars.
  ///
  /// In en, this message translates to:
  /// **'Paste bars'**
  String get pasteBars;

  /// No description provided for @repeatStart.
  ///
  /// In en, this message translates to:
  /// **'Repeat start'**
  String get repeatStart;

  /// No description provided for @repeatEnd.
  ///
  /// In en, this message translates to:
  /// **'Repeat end'**
  String get repeatEnd;

  /// No description provided for @playTimes.
  ///
  /// In en, this message translates to:
  /// **'Play {count} times'**
  String playTimes(int count);

  /// No description provided for @noRepeat.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get noRepeat;

  /// No description provided for @alternateEnding.
  ///
  /// In en, this message translates to:
  /// **'Alternate ending'**
  String get alternateEnding;

  /// No description provided for @endingN.
  ///
  /// In en, this message translates to:
  /// **'Ending {number}'**
  String endingN(int number);

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @targets.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get targets;

  /// No description provided for @jumps.
  ///
  /// In en, this message translates to:
  /// **'Jumps'**
  String get jumps;

  /// No description provided for @segno.
  ///
  /// In en, this message translates to:
  /// **'Segno'**
  String get segno;

  /// No description provided for @coda.
  ///
  /// In en, this message translates to:
  /// **'Coda'**
  String get coda;

  /// No description provided for @fine.
  ///
  /// In en, this message translates to:
  /// **'Fine'**
  String get fine;

  /// No description provided for @daCapo.
  ///
  /// In en, this message translates to:
  /// **'Da capo'**
  String get daCapo;

  /// No description provided for @daCapoAlFine.
  ///
  /// In en, this message translates to:
  /// **'Da capo al fine'**
  String get daCapoAlFine;

  /// No description provided for @daCapoAlCoda.
  ///
  /// In en, this message translates to:
  /// **'Da capo al coda'**
  String get daCapoAlCoda;

  /// No description provided for @dalSegno.
  ///
  /// In en, this message translates to:
  /// **'Dal segno'**
  String get dalSegno;

  /// No description provided for @dalSegnoAlFine.
  ///
  /// In en, this message translates to:
  /// **'Dal segno al fine'**
  String get dalSegnoAlFine;

  /// No description provided for @dalSegnoAlCoda.
  ///
  /// In en, this message translates to:
  /// **'Dal segno al coda'**
  String get dalSegnoAlCoda;

  /// No description provided for @toCoda.
  ///
  /// In en, this message translates to:
  /// **'To coda'**
  String get toCoda;

  /// No description provided for @addTrack.
  ///
  /// In en, this message translates to:
  /// **'Add track'**
  String get addTrack;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @mixer.
  ///
  /// In en, this message translates to:
  /// **'Mixer'**
  String get mixer;

  /// No description provided for @trackActions.
  ///
  /// In en, this message translates to:
  /// **'Track actions'**
  String get trackActions;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @removeTrack.
  ///
  /// In en, this message translates to:
  /// **'Remove track'**
  String get removeTrack;

  /// No description provided for @removeTrackQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String removeTrackQuestion(String name);

  /// No description provided for @removeTrackBody.
  ///
  /// In en, this message translates to:
  /// **'Its notes are removed too. Undo brings it back.'**
  String get removeTrackBody;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @renameTrack.
  ///
  /// In en, this message translates to:
  /// **'Rename track'**
  String get renameTrack;

  /// No description provided for @volumeOf.
  ///
  /// In en, this message translates to:
  /// **'Volume of {name}'**
  String volumeOf(String name);

  /// No description provided for @accidentals.
  ///
  /// In en, this message translates to:
  /// **'Accidentals'**
  String get accidentals;

  /// No description provided for @doubleFlat.
  ///
  /// In en, this message translates to:
  /// **'Double flat'**
  String get doubleFlat;

  /// No description provided for @flat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get flat;

  /// No description provided for @natural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get natural;

  /// No description provided for @sharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get sharp;

  /// No description provided for @doubleSharp.
  ///
  /// In en, this message translates to:
  /// **'Double sharp'**
  String get doubleSharp;

  /// No description provided for @dynamics.
  ///
  /// In en, this message translates to:
  /// **'Dynamics'**
  String get dynamics;

  /// No description provided for @pianississimo.
  ///
  /// In en, this message translates to:
  /// **'Pianississimo'**
  String get pianississimo;

  /// No description provided for @pianissimo.
  ///
  /// In en, this message translates to:
  /// **'Pianissimo'**
  String get pianissimo;

  /// No description provided for @piano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get piano;

  /// No description provided for @mezzoPiano.
  ///
  /// In en, this message translates to:
  /// **'Mezzo-piano'**
  String get mezzoPiano;

  /// No description provided for @mezzoForte.
  ///
  /// In en, this message translates to:
  /// **'Mezzo-forte'**
  String get mezzoForte;

  /// No description provided for @forte.
  ///
  /// In en, this message translates to:
  /// **'Forte'**
  String get forte;

  /// No description provided for @fortissimo.
  ///
  /// In en, this message translates to:
  /// **'Fortissimo'**
  String get fortissimo;

  /// No description provided for @fortississimo.
  ///
  /// In en, this message translates to:
  /// **'Fortississimo'**
  String get fortississimo;

  /// No description provided for @crescendo.
  ///
  /// In en, this message translates to:
  /// **'Crescendo'**
  String get crescendo;

  /// No description provided for @diminuendo.
  ///
  /// In en, this message translates to:
  /// **'Diminuendo'**
  String get diminuendo;

  /// No description provided for @guitarTechniques.
  ///
  /// In en, this message translates to:
  /// **'Guitar techniques'**
  String get guitarTechniques;

  /// No description provided for @hammerPull.
  ///
  /// In en, this message translates to:
  /// **'Hammer-on or pull-off'**
  String get hammerPull;

  /// No description provided for @slide.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get slide;

  /// No description provided for @bend.
  ///
  /// In en, this message translates to:
  /// **'Bend'**
  String get bend;

  /// No description provided for @vibrato.
  ///
  /// In en, this message translates to:
  /// **'Vibrato'**
  String get vibrato;

  /// No description provided for @bendRelease.
  ///
  /// In en, this message translates to:
  /// **'Bend and release'**
  String get bendRelease;

  /// No description provided for @prebend.
  ///
  /// In en, this message translates to:
  /// **'Pre-bend'**
  String get prebend;

  /// No description provided for @prebendRelease.
  ///
  /// In en, this message translates to:
  /// **'Pre-bend and release'**
  String get prebendRelease;

  /// No description provided for @bendKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get bendKind;

  /// No description provided for @bendAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get bendAmount;

  /// No description provided for @removeBend.
  ///
  /// In en, this message translates to:
  /// **'Remove bend'**
  String get removeBend;

  /// No description provided for @fullBend.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get fullBend;

  /// No description provided for @bendTone.
  ///
  /// In en, this message translates to:
  /// **'{amount} tone'**
  String bendTone(String amount);

  /// No description provided for @bendTones.
  ///
  /// In en, this message translates to:
  /// **'{amount} tones'**
  String bendTones(String amount);

  /// No description provided for @palmMute.
  ///
  /// In en, this message translates to:
  /// **'Palm mute'**
  String get palmMute;

  /// No description provided for @letRing.
  ///
  /// In en, this message translates to:
  /// **'Let ring'**
  String get letRing;

  /// No description provided for @deadNote.
  ///
  /// In en, this message translates to:
  /// **'Dead note'**
  String get deadNote;

  /// No description provided for @ghostNote.
  ///
  /// In en, this message translates to:
  /// **'Ghost note'**
  String get ghostNote;

  /// No description provided for @naturalHarmonic.
  ///
  /// In en, this message translates to:
  /// **'Natural harmonic'**
  String get naturalHarmonic;

  /// No description provided for @artificialHarmonic.
  ///
  /// In en, this message translates to:
  /// **'Artificial harmonic'**
  String get artificialHarmonic;

  /// No description provided for @tapping.
  ///
  /// In en, this message translates to:
  /// **'Tapping'**
  String get tapping;

  /// No description provided for @pickUp.
  ///
  /// In en, this message translates to:
  /// **'Pick up'**
  String get pickUp;

  /// No description provided for @pickDown.
  ///
  /// In en, this message translates to:
  /// **'Pick down'**
  String get pickDown;

  /// No description provided for @tremoloPicking.
  ///
  /// In en, this message translates to:
  /// **'Tremolo picking'**
  String get tremoloPicking;

  /// No description provided for @articulation.
  ///
  /// In en, this message translates to:
  /// **'Articulation'**
  String get articulation;

  /// No description provided for @accent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accent;

  /// No description provided for @marcato.
  ///
  /// In en, this message translates to:
  /// **'Marcato'**
  String get marcato;

  /// No description provided for @staccato.
  ///
  /// In en, this message translates to:
  /// **'Staccato'**
  String get staccato;

  /// No description provided for @tenuto.
  ///
  /// In en, this message translates to:
  /// **'Tenuto'**
  String get tenuto;

  /// No description provided for @fermata.
  ///
  /// In en, this message translates to:
  /// **'Fermata'**
  String get fermata;

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

  /// No description provided for @songTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get songTitle;

  /// No description provided for @changeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change title'**
  String get changeTitle;

  /// No description provided for @retune.
  ///
  /// In en, this message translates to:
  /// **'Retune…'**
  String get retune;

  /// No description provided for @retuneHeading.
  ///
  /// In en, this message translates to:
  /// **'Retune {track}'**
  String retuneHeading(String track);

  /// No description provided for @retuneHint.
  ///
  /// In en, this message translates to:
  /// **'Every note keeps its pitch; frets move.'**
  String get retuneHint;

  /// No description provided for @retuneHintFrets.
  ///
  /// In en, this message translates to:
  /// **'Every note keeps its string and fret, and sounds in the new tuning.'**
  String get retuneHintFrets;

  /// No description provided for @keepSound.
  ///
  /// In en, this message translates to:
  /// **'Keep the sound'**
  String get keepSound;

  /// No description provided for @keepFrets.
  ///
  /// In en, this message translates to:
  /// **'Keep the frets'**
  String get keepFrets;

  /// No description provided for @retuneConfirm.
  ///
  /// In en, this message translates to:
  /// **'Retune'**
  String get retuneConfirm;

  /// No description provided for @retuneReport.
  ///
  /// In en, this message translates to:
  /// **'{moved, plural, =0{No notes moved} =1{1 note moved to another string} other{{moved} notes moved to another string}}, {unplayable, plural, =0{all can be played} =1{1 can\'t be played} other{{unplayable} can\'t be played}}'**
  String retuneReport(int moved, int unplayable);

  /// No description provided for @octaveUp.
  ///
  /// In en, this message translates to:
  /// **'Octave up'**
  String get octaveUp;

  /// No description provided for @octaveDown.
  ///
  /// In en, this message translates to:
  /// **'Octave down'**
  String get octaveDown;

  /// No description provided for @unplayableOnOpen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note can\'t be played in this tuning. It\'s marked in red.} other{{count} notes can\'t be played in this tuning. They\'re marked in red.}}'**
  String unplayableOnOpen(int count);

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportGp.
  ///
  /// In en, this message translates to:
  /// **'Guitar Pro file (.gp)'**
  String get exportGp;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get exportPdf;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export: {error}'**
  String exportFailed(String error);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @strings.
  ///
  /// In en, this message translates to:
  /// **'Strings'**
  String get strings;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @tempoBpm.
  ///
  /// In en, this message translates to:
  /// **'Tempo (BPM)'**
  String get tempoBpm;

  /// No description provided for @timeSignature.
  ///
  /// In en, this message translates to:
  /// **'Time signature'**
  String get timeSignature;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @songActions.
  ///
  /// In en, this message translates to:
  /// **'Song actions'**
  String get songActions;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteSongQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteSongQuestion(String name);

  /// No description provided for @deleteSongBody.
  ///
  /// In en, this message translates to:
  /// **'The file is removed from this iPhone and can\'t be recovered.'**
  String get deleteSongBody;

  /// No description provided for @deleteEditedBody.
  ///
  /// In en, this message translates to:
  /// **'The original file and your edited copy are removed from this iPhone and can\'t be recovered.'**
  String get deleteEditedBody;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get edited;

  /// No description provided for @trackName.
  ///
  /// In en, this message translates to:
  /// **'Track name'**
  String get trackName;

  /// No description provided for @muteShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get muteShort;

  /// No description provided for @soloShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get soloShort;

  /// No description provided for @editFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make that change'**
  String get editFailed;

  /// No description provided for @editFailedNoChannel.
  ///
  /// In en, this message translates to:
  /// **'No MIDI channel is free for another track'**
  String get editFailedNoChannel;

  /// No description provided for @editFailedNoName.
  ///
  /// In en, this message translates to:
  /// **'A track needs a name'**
  String get editFailedNoName;

  /// No description provided for @editFailedLastGuitar.
  ///
  /// In en, this message translates to:
  /// **'The song keeps at least one guitar track'**
  String get editFailedLastGuitar;

  /// No description provided for @editFailedRepeat.
  ///
  /// In en, this message translates to:
  /// **'This bar ends a repeat that can\'t move'**
  String get editFailedRepeat;

  /// No description provided for @songChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the song: {error}'**
  String songChangeFailed(String error);

  /// No description provided for @exportAsGp.
  ///
  /// In en, this message translates to:
  /// **'Export as .gp'**
  String get exportAsGp;

  /// No description provided for @exportAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get exportAsPdf;

  /// No description provided for @revertToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Revert to original'**
  String get revertToOriginal;

  /// No description provided for @revert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revert;

  /// No description provided for @revertSongQuestion.
  ///
  /// In en, this message translates to:
  /// **'Revert \"{name}\"?'**
  String revertSongQuestion(String name);

  /// No description provided for @revertSongBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits are deleted, and the original file is listed again as it was.'**
  String get revertSongBody;

  /// No description provided for @renameSong.
  ///
  /// In en, this message translates to:
  /// **'Rename song'**
  String get renameSong;

  /// No description provided for @songName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get songName;

  /// No description provided for @nameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameEmpty;

  /// No description provided for @nameInvalid.
  ///
  /// In en, this message translates to:
  /// **'A name can\'t contain /, \\ or :'**
  String get nameInvalid;

  /// No description provided for @nameTaken.
  ///
  /// In en, this message translates to:
  /// **'Another song already has this name'**
  String get nameTaken;

  /// No description provided for @stringN.
  ///
  /// In en, this message translates to:
  /// **'String {number}'**
  String stringN(int number);
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
