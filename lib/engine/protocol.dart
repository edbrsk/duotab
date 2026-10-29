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

  /// Per bar; filled when the song is opened, empty in library summaries.
  final List<bool> barsWithNotes;

  const TrackSummary({
    required this.index,
    required this.name,
    required this.kind,
    required this.stringCount,
    required this.tuning,
    required this.midiProgram,
    this.barsWithNotes = const [],
  });

  factory TrackSummary.fromJson(Map<String, dynamic> json) => TrackSummary(
    index: json['index'] as int,
    name: json['name'] as String,
    kind: TrackKind.values.byName(json['kind'] as String),
    stringCount: json['stringCount'] as int?,
    tuning: (json['tuning'] as List<dynamic>?)?.cast<int>(),
    midiProgram: json['midiProgram'] as int,
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

  const SongSummary({
    required this.title,
    required this.tracks,
    this.bars = const [],
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

  const TrackMix({
    required this.index,
    required this.mute,
    required this.solo,
    required this.program,
  });

  Map<String, Object> toJson() => {
    'index': index,
    'mute': mute,
    'solo': solo,
    'program': program,
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

  const EditState({
    required this.position,
    required this.issues,
    required this.canUndo,
    required this.canRedo,
    required this.song,
    required this.edited,
    this.beatDuration,
    this.beatDots,
  });

  factory EditState.fromJson(Map<String, dynamic> json) {
    final beat = json['beat'] as Map<String, dynamic>?;
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
    );
  }
}

@immutable
sealed class EditCommand {
  const EditCommand();

  Map<String, Object> toJson();

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

  const SetFret(this.fret);

  @override
  Map<String, Object> toJson() => {'op': 'setFret', 'fret': fret};
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
