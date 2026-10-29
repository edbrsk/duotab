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

  @override
  String get libraryEmpty =>
      'Add Guitar Pro or MusicXML files in the Files app, under On My iPhone › DuoTab';

  @override
  String get unreadableFile => 'Can\'t open this file';

  @override
  String get newSong => 'New song';

  @override
  String stringsCount(int count) {
    return '$count strings';
  }

  @override
  String get noGuitarTrack => 'This song has no guitar track';

  @override
  String get noSongOpen => 'Open a song from the library';

  @override
  String get tracksHeading => 'Tracks';

  @override
  String scoreError(String message) {
    return 'Couldn\'t show this song: $message';
  }

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get loop => 'Loop';

  @override
  String tempoMarking(int bpm) {
    return '♩ = $bpm';
  }

  @override
  String get countIn => 'Count-in';

  @override
  String get metronome => 'Metronome';

  @override
  String get defaultTone => 'Default tone';

  @override
  String get toneClean => 'Clean';

  @override
  String get toneOverdrive => 'Overdrive';

  @override
  String get toneHighGain => 'High gain';

  @override
  String get licences => 'Licences';

  @override
  String muteTrack(String name) {
    return 'Mute $name';
  }

  @override
  String soloTrack(String name) {
    return 'Solo $name';
  }

  @override
  String get showTracks => 'Show tracks';

  @override
  String get hideTracks => 'Hide tracks';

  @override
  String get trackHeading => 'Track';

  @override
  String get tuning => 'Tuning';

  @override
  String get tone => 'Tone';

  @override
  String get hideTrackPanel => 'Hide track panel';

  @override
  String get showTrackPanel => 'Show track panel';

  @override
  String get notation => 'Notation';

  @override
  String get standardNotation => 'Standard notation';

  @override
  String get tab => 'Tab';
}
