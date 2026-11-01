// Mirrors engine/src/protocol.ts: change both together.

import 'dart:convert';

import 'package:flutter/foundation.dart';

enum TrackKind { guitar, drums, other }

class TrackSummary {
  final int index;
  final String name;
  final TrackKind kind;
  final int? stringCount;

  /// MIDI note numbers of the open strings, top string first.
  final List<int>? tuning;

  /// 0-based General MIDI program, as alphaTab stores it.
  final int midiProgram;

  /// 0–16, Guitar Pro's track volume.
  final int volume;

  /// The file's level; −∞ is [double.negativeInfinity].
  final double volumeDb;

  /// −1 full left … 1 full right.
  final double pan;

  /// The primary MIDI channel, which tells the track apart when tracks move.
  final int channel;

  /// Per bar; filled when the song is opened, empty in library summaries.
  final List<bool> barsWithNotes;

  const TrackSummary({
    required this.index,
    required this.name,
    required this.kind,
    required this.stringCount,
    required this.tuning,
    required this.midiProgram,
    this.volume = 12,
    this.volumeDb = 0,
    this.pan = 0,
    this.channel = 0,
    this.barsWithNotes = const [],
  });

  factory TrackSummary.fromJson(Map<String, dynamic> json) => TrackSummary(
    index: json['index'] as int,
    name: json['name'] as String,
    kind: TrackKind.values.byName(json['kind'] as String),
    stringCount: json['stringCount'] as int?,
    tuning: (json['tuning'] as List<dynamic>?)?.cast<int>(),
    midiProgram: json['midiProgram'] as int,
    volume: json['volume'] as int? ?? 12,
    volumeDb: json.containsKey('volumeDb')
        ? (json['volumeDb'] as num?)?.toDouble() ?? double.negativeInfinity
        : 0,
    pan: (json['pan'] as num?)?.toDouble() ?? 0,
    channel: json['channel'] as int? ?? 0,
    barsWithNotes:
        (json['barsWithNotes'] as List<dynamic>?)?.cast<bool>() ?? const [],
  );
}

class Section {
  final String marker;
  final String text;

  const Section({required this.marker, required this.text});

  factory Section.fromJson(Map<String, dynamic> json) =>
      Section(marker: json['marker'] as String, text: json['text'] as String);
}

/// Where the bar first plays, counting repeats.
class BarInfo {
  final int index;
  final int startTick;
  final int startMs;
  final double tempo;
  final Section? section;

  const BarInfo({
    required this.index,
    required this.startTick,
    required this.startMs,
    required this.tempo,
    this.section,
  });

  factory BarInfo.fromJson(Map<String, dynamic> json) => BarInfo(
    index: json['index'] as int,
    startTick: json['startTick'] as int,
    startMs: json['startMs'] as int,
    tempo: (json['tempo'] as num).toDouble(),
    section: switch (json['section']) {
      final Map<String, dynamic> section => Section.fromJson(section),
      _ => null,
    },
  );
}

class SongSummary {
  final String title;
  final List<TrackSummary> tracks;

  /// Filled when the song is opened, empty in library summaries.
  final List<BarInfo> bars;

  /// Notes automatic fingering on open could not place; 0 elsewhere.
  final int unplayableNotes;

  final double masterDb;

  const SongSummary({
    required this.title,
    required this.tracks,
    this.bars = const [],
    this.unplayableNotes = 0,
    this.masterDb = 0,
  });

  factory SongSummary.fromJson(Map<String, dynamic> json) => SongSummary(
    title: json['title'] as String,
    tracks: [
      for (final t in json['tracks'] as List<dynamic>)
        TrackSummary.fromJson(t as Map<String, dynamic>),
    ],
    bars: [
      for (final b in (json['bars'] as List<dynamic>?) ?? const [])
        BarInfo.fromJson(b as Map<String, dynamic>),
    ],
    unplayableNotes: json['unplayableNotes'] as int? ?? 0,
    masterDb: (json['masterDb'] as num?)?.toDouble() ?? 0,
  );

  List<TrackSummary> get guitarTracks =>
      tracks.where((t) => t.kind == TrackKind.guitar).toList();
}

/// An A–B loop, in MIDI ticks.
class PlaybackRange {
  final int startTick;
  final int endTick;

  const PlaybackRange({required this.startTick, required this.endTick});

  factory PlaybackRange.fromJson(Map<String, dynamic> json) => PlaybackRange(
    startTick: (json['startTick'] as num).toInt(),
    endTick: (json['endTick'] as num).toInt(),
  );

  Map<String, Object> toJson() => {'startTick': startTick, 'endTick': endTick};
}

class TrackMix {
  final int index;
  final bool mute;
  final bool solo;

  /// 0-based General MIDI program.
  final int program;

  /// −∞ is [double.negativeInfinity].
  final double volumeDb;

  /// −1 full left … 1 full right.
  final double pan;

  const TrackMix({
    required this.index,
    required this.mute,
    required this.solo,
    required this.program,
    required this.volumeDb,
    required this.pan,
  });

  Map<String, Object?> toJson() => {
    'index': index,
    'mute': mute,
    'solo': solo,
    'program': program,
    'volumeDb': volumeDb.isFinite ? volumeDb : null,
    'pan': pan,
  };
}

class StaffView {
  final int index;
  final bool notation;
  final bool tab;

  const StaffView({
    required this.index,
    required this.notation,
    required this.tab,
  });

  Map<String, Object> toJson() => {
    'index': index,
    'notation': notation,
    'tab': tab,
  };
}

class EngineEvent {
  /// `ready`, `rendered`, `error`, `playerState`, `position`,
  /// `rangeChanged` or `tapped`.
  final String type;
  final Map<String, dynamic> payload;

  const EngineEvent(this.type, this.payload);
}

/// alphaTab numbers strings from the lowest: string 1 is the lowest-pitched.
@immutable
class EditPosition {
  final int track;
  final int bar;
  final int voice;
  final int beat;
  final int string;

  const EditPosition({
    required this.track,
    required this.bar,
    required this.voice,
    required this.beat,
    required this.string,
  });

  factory EditPosition.fromJson(Map<String, dynamic> json) => EditPosition(
    track: json['track'] as int,
    bar: json['bar'] as int,
    voice: json['voice'] as int,
    beat: json['beat'] as int,
    string: json['string'] as int,
  );

  Map<String, Object> toJson() => {
    'track': track,
    'bar': bar,
    'voice': voice,
    'beat': beat,
    'string': string,
  };

  @override
  bool operator ==(Object other) =>
      other is EditPosition &&
      other.track == track &&
      other.bar == bar &&
      other.voice == voice &&
      other.beat == beat &&
      other.string == string;

  @override
  int get hashCode => Object.hash(track, bar, voice, beat, string);
}

/// A voice whose notes and rests don't add up to its bar; negative
/// [ticksOff] means short.
class BarIssue {
  final int bar;
  final int voice;
  final int ticksOff;

  const BarIssue({
    required this.bar,
    required this.voice,
    required this.ticksOff,
  });

  factory BarIssue.fromJson(Map<String, dynamic> json) => BarIssue(
    bar: json['bar'] as int,
    voice: json['voice'] as int,
    ticksOff: json['ticksOff'] as int,
  );
}

class EditState {
  /// Null until the owner taps a string.
  final EditPosition? position;
  final List<BarIssue> issues;
  final bool canUndo;
  final bool canRedo;
  final SongSummary song;

  /// True when the song changed, so it needs saving.
  final bool edited;

  /// The note value of the beat under the cursor, which the palette shows.
  final int? beatDuration;
  final int? beatDots;

  /// Engine `TechniqueId`s on the cursor's beat and the cursor string's note.
  final Set<String> techniques;

  /// `ppp` … `fff`; null for no cursor or a dynamic the palette doesn't offer.
  final String? dynamicMark;

  /// 1 for none; 3, 5 or 6.
  final int tuplet;

  /// The cursor string has a note, so note techniques apply.
  final bool hasNote;

  /// `bend`, `bendRelease`, `prebend` or `prebendRelease`; null for no bend
  /// or a shape the palette doesn't offer.
  final String? bendKind;

  /// In quarter tones, 1–12.
  final int bendAmount;

  /// The cursor beat's chord name; its spec is null for a name DuoScore
  /// can't build, such as "N.C.".
  final String? chordName;
  final ChordSpec? chordSpec;

  /// The cursor beat's notes, low string first, −1 where none.
  final List<int> beatFrets;

  /// The cursor bar's properties, as the engine's `BarProperties`.
  final int barNumerator;
  final int barDenominator;

  /// −7 (seven flats) to 7 (seven sharps).
  final int barKey;
  final bool barMinor;

  /// `treble` or `bass`; null for a clef the palette doesn't offer.
  final String? barClef;
  final int barTempo;

  /// The bar has its own tempo marking; always true for the first bar.
  final bool barTempoChange;
  final bool canPaste;

  /// The cursor bar's form, as the engine's `Structure`.
  final bool repeatStart;

  /// How many times the repeat plays; 0 when the bar ends no repeat.
  final int repeatCount;

  /// Ascending, 1–8.
  final List<int> endings;

  /// Engine `DirectionId`s, such as `segno` or `dalSegnoAlCoda`.
  final Set<String> directions;

  /// The track the engine draws, which track edits can change.
  final int? drawnTrack;

  /// After a retune, until the next edit, undo or redo.
  final RetuneReport? retune;

  const EditState({
    required this.position,
    required this.issues,
    required this.canUndo,
    required this.canRedo,
    required this.song,
    required this.edited,
    this.beatDuration,
    this.beatDots,
    this.techniques = const {},
    this.dynamicMark,
    this.tuplet = 1,
    this.hasNote = false,
    this.bendKind,
    this.bendAmount = 4,
    this.chordName,
    this.chordSpec,
    this.beatFrets = const [],
    this.barNumerator = 4,
    this.barDenominator = 4,
    this.barKey = 0,
    this.barMinor = false,
    this.barClef,
    this.barTempo = 120,
    this.barTempoChange = false,
    this.canPaste = false,
    this.repeatStart = false,
    this.repeatCount = 0,
    this.endings = const [],
    this.directions = const {},
    this.drawnTrack,
    this.retune,
  });

  factory EditState.fromJson(Map<String, dynamic> json) {
    final beat = json['beat'] as Map<String, dynamic>?;
    final bend = beat?['bend'] as Map<String, dynamic>?;
    final chord = beat?['chord'] as Map<String, dynamic>?;
    final bar = json['bar'] as Map<String, dynamic>?;
    final structure = json['structure'] as Map<String, dynamic>?;
    return EditState(
      position: switch (json['position']) {
        final Map<String, dynamic> p => EditPosition.fromJson(p),
        _ => null,
      },
      issues: [
        for (final i in json['issues'] as List<dynamic>)
          BarIssue.fromJson(i as Map<String, dynamic>),
      ],
      canUndo: json['canUndo'] as bool,
      canRedo: json['canRedo'] as bool,
      song: SongSummary.fromJson(json['song'] as Map<String, dynamic>),
      edited: json['edited'] as bool,
      beatDuration: beat?['duration'] as int?,
      beatDots: beat?['dots'] as int?,
      techniques: {
        for (final t in beat?['techniques'] as List<dynamic>? ?? const [])
          t as String,
      },
      dynamicMark: beat?['dynamic'] as String?,
      tuplet: beat?['tuplet'] as int? ?? 1,
      hasNote: beat?['hasNote'] as bool? ?? false,
      bendKind: bend?['kind'] as String?,
      bendAmount: bend?['amount'] as int? ?? 4,
      chordName: chord?['name'] as String?,
      chordSpec: switch (chord?['spec']) {
        final Map<String, dynamic> spec => ChordSpec.fromJson(spec),
        _ => null,
      },
      beatFrets: [
        for (final f in beat?['frets'] as List<dynamic>? ?? const []) f as int,
      ],
      barNumerator: bar?['numerator'] as int? ?? 4,
      barDenominator: bar?['denominator'] as int? ?? 4,
      barKey: bar?['key'] as int? ?? 0,
      barMinor: bar?['minor'] as bool? ?? false,
      barClef: bar?['clef'] as String?,
      barTempo: (bar?['tempo'] as num?)?.round() ?? 120,
      barTempoChange: bar?['tempoChange'] as bool? ?? false,
      canPaste: json['canPaste'] as bool? ?? false,
      repeatStart: structure?['repeatStart'] as bool? ?? false,
      repeatCount: structure?['repeatCount'] as int? ?? 0,
      endings: [
        for (final e in structure?['endings'] as List<dynamic>? ?? const [])
          e as int,
      ],
      directions: {
        for (final d in structure?['directions'] as List<dynamic>? ?? const [])
          d as String,
      },
      drawnTrack: json['drawnTrack'] as int?,
      retune: switch (json['retune']) {
        final Map<String, dynamic> r => RetuneReport.fromJson(r),
        _ => null,
      },
    );
  }
}

/// What a retune moved to another string or could not place.
class RetuneReport {
  final int track;

  /// MIDI note numbers of the open strings, top string first.
  final List<int> tuning;
  final int octave;

  /// The retune kept each note's string and fret, not its sound.
  final bool keepFrets;
  final int moved;
  final int unplayable;

  const RetuneReport({
    required this.track,
    required this.tuning,
    required this.octave,
    required this.moved,
    required this.unplayable,
    this.keepFrets = false,
  });

  factory RetuneReport.fromJson(Map<String, dynamic> json) => RetuneReport(
    track: json['track'] as int,
    tuning: [for (final n in json['tuning'] as List<dynamic>) n as int],
    octave: json['octave'] as int,
    keepFrets: json['keep'] == 'frets',
    moved: json['moved'] as int,
    unplayable: json['unplayable'] as int,
  );
}

@immutable
sealed class EditCommand {
  const EditCommand();

  Map<String, Object?> toJson();

  // Value equality, so a command can be matched in mocks and tests.
  @override
  bool operator ==(Object other) =>
      other is EditCommand &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

class SetFret extends EditCommand {
  final int fret;

  /// The second digit of a two-digit fret, which shares the first digit's
  /// undo step.
  final bool combine;

  const SetFret(this.fret, {this.combine = false});

  @override
  Map<String, Object> toJson() => {
    'op': 'setFret',
    'fret': fret,
    if (combine) 'combine': true,
  };
}

class DeleteNote extends EditCommand {
  const DeleteNote();

  @override
  Map<String, Object> toJson() => {'op': 'deleteNote'};
}

class SetDuration extends EditCommand {
  /// alphaTab's `Duration`: 1 whole, 2 half, 4 quarter … 64.
  final int duration;
  final int dots;

  const SetDuration(this.duration, this.dots);

  @override
  Map<String, Object> toJson() => {
    'op': 'setDuration',
    'duration': duration,
    'dots': dots,
  };
}

class SetRest extends EditCommand {
  const SetRest();

  @override
  Map<String, Object> toJson() => {'op': 'setRest'};
}

class SelectVoice extends EditCommand {
  /// 0-based.
  final int voice;

  const SelectVoice(this.voice);

  @override
  Map<String, Object> toJson() => {'op': 'selectVoice', 'voice': voice};
}

class Move extends EditCommand {
  /// `left`, `right`, `up` or `down`.
  final String direction;

  const Move(this.direction);

  @override
  Map<String, Object> toJson() => {'op': 'move', 'direction': direction};
}

class Toggle extends EditCommand {
  /// An engine `TechniqueId`, such as `palmMute`.
  final String technique;

  const Toggle(this.technique);

  @override
  Map<String, Object> toJson() => {'op': 'toggle', 'technique': technique};
}

class SetDynamic extends EditCommand {
  /// `ppp` … `fff`.
  final String mark;

  const SetDynamic(this.mark);

  @override
  Map<String, Object> toJson() => {'op': 'setDynamic', 'dynamic': mark};
}

class SetTuplet extends EditCommand {
  /// 1 for none; 3, 5 or 6.
  final int tuplet;

  const SetTuplet(this.tuplet);

  @override
  Map<String, Object> toJson() => {'op': 'setTuplet', 'tuplet': tuplet};
}

class AddGrace extends EditCommand {
  const AddGrace();

  @override
  Map<String, Object> toJson() => {'op': 'addGrace'};
}

/// A chord symbol: `root` and `bass` are pitch classes, C = 0; engine
/// `ChordType`s and `ChordAddition`s, such as `maj7` and `b9`.
@immutable
class ChordSpec {
  final int root;
  final String type;
  final List<String> additions;
  final int? bass;

  const ChordSpec({
    required this.root,
    required this.type,
    required this.additions,
    required this.bass,
  });

  factory ChordSpec.fromJson(Map<String, dynamic> json) => ChordSpec(
    root: json['root'] as int,
    type: json['type'] as String,
    additions: [
      for (final a in json['additions'] as List<dynamic>) a as String,
    ],
    bass: json['bass'] as int?,
  );

  Map<String, Object?> toJson() => {
    'root': root,
    'type': type,
    'additions': additions,
    'bass': bass,
  };

  @override
  bool operator ==(Object other) =>
      other is ChordSpec &&
      other.root == root &&
      other.type == type &&
      other.bass == bass &&
      other.additions.toSet().containsAll(additions) &&
      additions.toSet().containsAll(other.additions);

  @override
  int get hashCode =>
      Object.hash(root, type, bass, Object.hashAllUnordered(additions));
}

/// Frets low string first, −1 for a string not played.
class ChordPosition {
  final List<int> frets;

  /// An open string in a shape no higher than the 4th fret.
  final bool open;

  /// 0 when nothing is fretted.
  final int lowestFret;

  const ChordPosition({
    required this.frets,
    required this.open,
    required this.lowestFret,
  });

  factory ChordPosition.fromJson(Map<String, dynamic> json) => ChordPosition(
    frets: [for (final f in json['frets'] as List<dynamic>) f as int],
    open: json['open'] as bool,
    lowestFret: json['lowestFret'] as int,
  );
}

class ChordPositions {
  final String name;
  final List<ChordPosition> positions;

  const ChordPositions({required this.name, required this.positions});

  factory ChordPositions.fromJson(Map<String, dynamic> json) => ChordPositions(
    name: json['name'] as String,
    positions: [
      for (final p in json['positions'] as List<dynamic>)
        ChordPosition.fromJson(p as Map<String, dynamic>),
    ],
  );
}

class SetChord extends EditCommand {
  final ChordSpec chord;

  /// One of the chord's positions, low string first.
  final List<int> frets;

  const SetChord(this.chord, this.frets);

  @override
  Map<String, Object?> toJson() => {
    'op': 'setChord',
    'chord': chord.toJson(),
    'frets': frets,
  };
}

class SetBend extends EditCommand {
  /// Null removes the bend.
  final String? kind;

  /// In quarter tones, 1–12.
  final int amount;

  const SetBend(this.kind, this.amount);

  @override
  Map<String, Object?> toJson() => {
    'op': 'setBend',
    'bend': kind == null ? null : {'kind': kind, 'amount': amount},
  };
}

/// Needs no cursor.
class SetTitle extends EditCommand {
  final String title;

  const SetTitle(this.title);

  @override
  Map<String, Object> toJson() => {'op': 'setTitle', 'title': title};
}

class SetTimeSignature extends EditCommand {
  final int numerator;
  final int denominator;

  const SetTimeSignature(this.numerator, this.denominator);

  @override
  Map<String, Object> toJson() => {
    'op': 'setTimeSignature',
    'numerator': numerator,
    'denominator': denominator,
  };
}

class SetTempo extends EditCommand {
  /// Null removes the bar's tempo marking.
  final int? bpm;

  const SetTempo(this.bpm);

  @override
  Map<String, Object?> toJson() => {'op': 'setTempo', 'bpm': bpm};
}

class SetKeySignature extends EditCommand {
  /// −7 (seven flats) to 7 (seven sharps).
  final int key;
  final bool minor;

  const SetKeySignature(this.key, {required this.minor});

  @override
  Map<String, Object> toJson() => {
    'op': 'setKeySignature',
    'key': key,
    'minor': minor,
  };
}

class SetClef extends EditCommand {
  /// `treble` or `bass`.
  final String clef;

  const SetClef(this.clef);

  @override
  Map<String, Object> toJson() => {'op': 'setClef', 'clef': clef};
}

class InsertBar extends EditCommand {
  const InsertBar();

  @override
  Map<String, Object> toJson() => {'op': 'insertBar'};
}

class DeleteBar extends EditCommand {
  const DeleteBar();

  @override
  Map<String, Object> toJson() => {'op': 'deleteBar'};
}

class CopyBars extends EditCommand {
  const CopyBars();

  @override
  Map<String, Object> toJson() => {'op': 'copyBars'};
}

class PasteBars extends EditCommand {
  const PasteBars();

  @override
  Map<String, Object> toJson() => {'op': 'pasteBars'};
}

class ToggleRepeatStart extends EditCommand {
  const ToggleRepeatStart();

  @override
  Map<String, Object> toJson() => {'op': 'toggleRepeatStart'};
}

class SetRepeatEnd extends EditCommand {
  /// How many times the repeat plays, 2–8; 0 removes the repeat end.
  final int count;

  const SetRepeatEnd(this.count);

  @override
  Map<String, Object> toJson() => {'op': 'setRepeatEnd', 'count': count};
}

class ToggleEnding extends EditCommand {
  /// 1–8.
  final int ending;

  const ToggleEnding(this.ending);

  @override
  Map<String, Object> toJson() => {'op': 'toggleEnding', 'ending': ending};
}

class ToggleDirection extends EditCommand {
  /// An engine `DirectionId`.
  final String direction;

  const ToggleDirection(this.direction);

  @override
  Map<String, Object> toJson() => {
    'op': 'toggleDirection',
    'direction': direction,
  };
}

/// Track edits need no cursor.
class AddTrack extends EditCommand {
  /// MIDI note numbers of the open strings, top string first.
  final List<int> tuning;
  final int program;

  const AddTrack(this.tuning, this.program);

  @override
  Map<String, Object> toJson() => {
    'op': 'addTrack',
    'tuning': tuning,
    'program': program,
  };
}

class RemoveTrack extends EditCommand {
  final int track;

  const RemoveTrack(this.track);

  @override
  Map<String, Object> toJson() => {'op': 'removeTrack', 'track': track};
}

class MoveTrack extends EditCommand {
  final int track;
  final int to;

  const MoveTrack(this.track, this.to);

  @override
  Map<String, Object> toJson() => {'op': 'moveTrack', 'track': track, 'to': to};
}

class RenameTrack extends EditCommand {
  final int track;
  final String name;

  const RenameTrack(this.track, this.name);

  @override
  Map<String, Object> toJson() => {
    'op': 'renameTrack',
    'track': track,
    'name': name,
  };
}

/// Keeps every note's sound, [octave] (−2 to 2) shifting them all; with
/// [keepFrets], keeps every string and fret instead, at octave 0.
class RetuneTrack extends EditCommand {
  final int track;
  final List<int> tuning;
  final int octave;
  final bool keepFrets;

  const RetuneTrack(
    this.track,
    this.tuning,
    this.octave, {
    this.keepFrets = false,
  });

  @override
  Map<String, Object> toJson() => {
    'op': 'retune',
    'track': track,
    'tuning': tuning,
    'octave': octave,
    'keep': keepFrets ? 'frets' : 'pitch',
  };
}

class Place extends EditCommand {
  final EditPosition position;

  const Place(this.position);

  @override
  Map<String, Object> toJson() => {
    'op': 'place',
    'position': position.toJson(),
  };
}

class NewSongOptions {
  final String title;

  /// MIDI note numbers of the open strings, top string first.
  final List<int> tuning;
  final int tempo;
  final int numerator;
  final int denominator;

  const NewSongOptions({
    required this.title,
    required this.tuning,
    required this.tempo,
    required this.numerator,
    required this.denominator,
  });

  Map<String, Object> toJson() => {
    'title': title,
    'tuning': tuning,
    'tempo': tempo,
    'numerator': numerator,
    'denominator': denominator,
  };
}

/// One HTML document per A4 page; [baseUrl] is the engine's origin, which
/// serves the music font.
class PdfPages {
  final List<String> pages;
  final String baseUrl;

  const PdfPages({required this.pages, required this.baseUrl});

  factory PdfPages.fromJson(Map<String, dynamic> json) => PdfPages(
    pages: [for (final page in json['pages'] as List) page as String],
    baseUrl: json['baseUrl'] as String,
  );
}
