// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DuoScore';

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
  String get widerToEdit => 'Make DuoScore wider to edit';

  @override
  String get libraryEmpty => 'Tap Import to add Guitar Pro or MusicXML files';

  @override
  String get importSongs => 'Import';

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

  @override
  String get fret => 'Fret';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get previousBeat => 'Previous beat';

  @override
  String get nextBeat => 'Next beat';

  @override
  String get stringUp => 'String up';

  @override
  String get stringDown => 'String down';

  @override
  String get hidePalette => 'Hide palette';

  @override
  String get showPalette => 'Show palette';

  @override
  String get voice => 'Voice';

  @override
  String get noteValue => 'Note value';

  @override
  String get rests => 'Rests';

  @override
  String get dots => 'Dots';

  @override
  String voiceN(int number) {
    return 'Voice $number';
  }

  @override
  String get wholeNote => 'Whole note';

  @override
  String get halfNote => 'Half note';

  @override
  String get quarterNote => 'Quarter note';

  @override
  String get eighthNote => 'Eighth note';

  @override
  String get sixteenthNote => 'Sixteenth note';

  @override
  String get thirtySecondNote => 'Thirty-second note';

  @override
  String get sixtyFourthNote => 'Sixty-fourth note';

  @override
  String get wholeRest => 'Whole rest';

  @override
  String get halfRest => 'Half rest';

  @override
  String get quarterRest => 'Quarter rest';

  @override
  String get eighthRest => 'Eighth rest';

  @override
  String get sixteenthRest => 'Sixteenth rest';

  @override
  String get thirtySecondRest => 'Thirty-second rest';

  @override
  String get sixtyFourthRest => 'Sixty-fourth rest';

  @override
  String get dot => 'Dot';

  @override
  String get doubleDot => 'Double dot';

  @override
  String get triplet => 'Triplet';

  @override
  String get quintuplet => 'Quintuplet';

  @override
  String get sextuplet => 'Sextuplet';

  @override
  String get tie => 'Tie';

  @override
  String get graceNote => 'Grace note';

  @override
  String get accidentals => 'Accidentals';

  @override
  String get doubleFlat => 'Double flat';

  @override
  String get flat => 'Flat';

  @override
  String get natural => 'Natural';

  @override
  String get sharp => 'Sharp';

  @override
  String get doubleSharp => 'Double sharp';

  @override
  String get dynamics => 'Dynamics';

  @override
  String get pianississimo => 'Pianississimo';

  @override
  String get pianissimo => 'Pianissimo';

  @override
  String get piano => 'Piano';

  @override
  String get mezzoPiano => 'Mezzo-piano';

  @override
  String get mezzoForte => 'Mezzo-forte';

  @override
  String get forte => 'Forte';

  @override
  String get fortissimo => 'Fortissimo';

  @override
  String get fortississimo => 'Fortississimo';

  @override
  String get crescendo => 'Crescendo';

  @override
  String get diminuendo => 'Diminuendo';

  @override
  String get guitarTechniques => 'Guitar techniques';

  @override
  String get hammerPull => 'Hammer-on or pull-off';

  @override
  String get slide => 'Slide';

  @override
  String get bend => 'Bend';

  @override
  String get vibrato => 'Vibrato';

  @override
  String get bendRelease => 'Bend and release';

  @override
  String get prebend => 'Pre-bend';

  @override
  String get prebendRelease => 'Pre-bend and release';

  @override
  String get bendKind => 'Type';

  @override
  String get bendAmount => 'Amount';

  @override
  String get removeBend => 'Remove bend';

  @override
  String get fullBend => 'Full';

  @override
  String bendTone(String amount) {
    return '$amount tone';
  }

  @override
  String bendTones(String amount) {
    return '$amount tones';
  }

  @override
  String get palmMute => 'Palm mute';

  @override
  String get letRing => 'Let ring';

  @override
  String get deadNote => 'Dead note';

  @override
  String get ghostNote => 'Ghost note';

  @override
  String get naturalHarmonic => 'Natural harmonic';

  @override
  String get artificialHarmonic => 'Artificial harmonic';

  @override
  String get tapping => 'Tapping';

  @override
  String get pickUp => 'Pick up';

  @override
  String get pickDown => 'Pick down';

  @override
  String get tremoloPicking => 'Tremolo picking';

  @override
  String get articulation => 'Articulation';

  @override
  String get accent => 'Accent';

  @override
  String get marcato => 'Marcato';

  @override
  String get staccato => 'Staccato';

  @override
  String get tenuto => 'Tenuto';

  @override
  String get fermata => 'Fermata';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get songTitle => 'Title';

  @override
  String get changeTitle => 'Change title';

  @override
  String get save => 'Save';

  @override
  String get strings => 'Strings';

  @override
  String get custom => 'Custom';

  @override
  String get tempoBpm => 'Tempo (BPM)';

  @override
  String get timeSignature => 'Time signature';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get songActions => 'Song actions';

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String deleteSongQuestion(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteSongBody =>
      'The file is removed from this iPhone and can\'t be recovered.';

  @override
  String get renameSong => 'Rename song';

  @override
  String get songName => 'Name';

  @override
  String get nameEmpty => 'Enter a name';

  @override
  String get nameInvalid => 'A name can\'t contain /, \\ or :';

  @override
  String get nameTaken => 'Another song already has this name';

  @override
  String stringN(int number) {
    return 'String $number';
  }
}
