import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/duo/hinge_status_provider.dart';
import '../../engine/engine_bridge.dart';
import '../../engine/protocol.dart';
import '../score/score_cubit.dart';
import '../settings/settings_cubit.dart';
import 'practice_settings.dart';
import 'practice_store.dart';
import 'resolve_practice.dart';
import 'tone.dart';

class PlaybackState {
  final bool playing;

  /// The bar under the playback position.
  final int bar;
  final PracticeSettings practice;

  const PlaybackState({
    this.playing = false,
    this.bar = 0,
    this.practice = const PracticeSettings(),
  });

  PlaybackState copyWith({
    bool? playing,
    int? bar,
    PracticeSettings? practice,
  }) => PlaybackState(
    playing: playing ?? this.playing,
    bar: bar ?? this.bar,
    practice: practice ?? this.practice,
  );
}

class PlaybackCubit extends Cubit<PlaybackState> {
  final EngineBridge engine;
  final HingeStatusProvider hinge;
  final ScoreCubit score;
  final PracticeStore practice;
  final SettingsCubit settings;

  late final StreamSubscription<EngineEvent> _events;
  late final StreamSubscription<ScoreState> _songs;
  late final StreamSubscription<AppSettings> _settings;
  SongSummary? _song;
  int? _openId;
  String? _path;

  /// False from a song's arrival until its practice settings are applied;
  /// edits and range events meanwhile would land on the wrong song's settings.
  var _practiceReady = false;

  PlaybackCubit({
    required this.engine,
    required this.hinge,
    required this.score,
    required this.practice,
    required this.settings,
  }) : super(const PlaybackState()) {
    _events = engine.events.listen(_onEngineEvent);
    _songs = score.stream.listen(_onScoreChanged);
    _settings = settings.stream.listen((_) => unawaited(_sendPlayerOptions()));
    hinge.addListener(_onHingeChanged);
    unawaited(_sendPlayerOptions());
  }

  Future<void> _sendPlayerOptions() => _send(
    () => engine.setPlayerOptions(
      countIn: settings.state.countIn,
      metronome: settings.state.metronome,
    ),
  );

  // A new openId means the engine loaded a song, even the same file again
  // after a restart; its player starts over at bar 0. An edit or a move to
  // the song's "(DuoScore)" copy keeps the same song.
  void _onScoreChanged(ScoreState scoreState) {
    final song = scoreState.song;
    if (song == null) {
      // Closed, as when its file was deleted: nothing more is saved for it.
      if (scoreState.openId != _openId && _openId != null) {
        _openId = scoreState.openId;
        _song = null;
        _path = null;
        _practiceReady = false;
        emit(state.copyWith(playing: false, bar: 0));
      }
      return;
    }
    if (scoreState.openId == _openId) {
      _song = song;
      if (scoreState.path != _path) {
        _path = scoreState.path;
        if (_practiceReady) unawaited(practice.save(_path!, state.practice));
      }
      return;
    }
    _openId = scoreState.openId;
    _song = song;
    _path = scoreState.path;
    _practiceReady = false;
    emit(
      state.copyWith(
        playing: false,
        bar: 0,
        practice: const PracticeSettings(),
      ),
    );
    unawaited(_applyPractice(song, scoreState.path!));
  }

  Future<void> _applyPractice(SongSummary song, String path) async {
    final openId = _openId;
    final resolved = resolvePractice(
      song,
      await practice.load(path),
      settings.state.defaultTone,
    );
    if (openId != _openId) return;
    emit(state.copyWith(practice: resolved));
    _practiceReady = true;
    final hidden = [
      for (final t in song.tracks)
        if (resolved.tracks[t.index] case final p?
            when !p.showNotation || !p.showTab)
          StaffView(index: t.index, notation: p.showNotation, tab: p.showTab),
    ];
    for (final command in [
      () => engine.setTracks([for (final t in song.tracks) _mix(t)]),
      if (hidden.isNotEmpty) () => engine.setStaves(hidden),
      () => engine.setSpeed(resolved.speed),
      () => engine.setLooping(looping: resolved.looping),
      () => engine.setRange(resolved.range),
    ]) {
      if (openId != _openId) return;
      await _send(command);
    }
  }

  Future<void> setSpeed(double speed) async {
    if (!_practiceReady) return;
    // 5% steps; dividing a whole number of steps gives the exact literal.
    final value = (speed.clamp(0.25, 1.5) * 20).round() / 20;
    await Future.wait([
      _updatePractice(state.practice.copyWith(speed: value)),
      _send(() => engine.setSpeed(value)),
    ]);
  }

  Future<void> setLooping({required bool on}) async {
    if (!_practiceReady) return;
    await Future.wait([
      _updatePractice(state.practice.copyWith(looping: on)),
      _send(() => engine.setLooping(looping: on)),
    ]);
  }

  Future<void> _updatePractice(PracticeSettings settings) async {
    if (!_practiceReady) return;
    emit(state.copyWith(practice: settings));
    await practice.save(_path!, settings);
  }

  TrackMix _mix(TrackSummary track) {
    final p = state.practice.tracks[track.index] ?? const TrackPractice();
    return TrackMix(
      index: track.index,
      mute: p.mute,
      solo: p.solo,
      program: p.tone?.program ?? track.midiProgram,
    );
  }

  Future<void> setMute(int track, {required bool on}) =>
      _updateTrack(track, (p) => p.copyWith(mute: on));

  Future<void> setSolo(int track, {required bool on}) =>
      _updateTrack(track, (p) => p.copyWith(solo: on));

  Future<void> setTone(int track, Tone tone) =>
      _updateTrack(track, (p) => p.copyWith(tone: tone));

  Future<void> setStaffView(
    int track, {
    required bool notation,
    required bool tab,
  }) async {
    final song = _song;
    if (!_practiceReady || song == null || track >= song.tracks.length) return;
    final tracks = {...state.practice.tracks};
    tracks[track] = (tracks[track] ?? const TrackPractice()).copyWith(
      showNotation: notation,
      showTab: tab,
    );
    await Future.wait([
      _updatePractice(state.practice.copyWith(tracks: tracks)),
      _send(
        () => engine.setStaves([
          StaffView(index: track, notation: notation, tab: tab),
        ]),
      ),
    ]);
  }

  Future<void> _updateTrack(
    int index,
    TrackPractice Function(TrackPractice) change,
  ) async {
    final song = _song;
    if (!_practiceReady || song == null || index >= song.tracks.length) return;
    final tracks = {...state.practice.tracks};
    tracks[index] = change(tracks[index] ?? const TrackPractice());
    await Future.wait([
      _updatePractice(state.practice.copyWith(tracks: tracks)),
      _send(() => engine.setTracks([_mix(song.tracks[index])])),
    ]);
  }

  void _onEngineEvent(EngineEvent event) {
    switch (event.type) {
      case 'playerState':
        emit(state.copyWith(playing: event.payload['playing'] == true));
      case 'position':
        emit(state.copyWith(bar: event.payload['bar'] as int));
      case 'rangeChanged':
        final range = switch (event.payload['range']) {
          final Map<String, dynamic> json => PlaybackRange.fromJson(json),
          _ => null,
        };
        unawaited(_updatePractice(state.practice.copyWith(range: () => range)));
      // A ready after start-up means the page reloaded, and its player with it.
      case 'ready':
        emit(state.copyWith(playing: false));
        unawaited(_sendPlayerOptions());
    }
  }

  void _onHingeChanged() {
    if (!hinge.isOpen) unawaited(pause());
  }

  Future<void> playPause() => state.playing ? pause() : _send(engine.play);

  Future<void> pause() => _send(engine.pause);

  Future<void> stop() => _send(engine.stop);

  Future<void> seekBar(int bar) => _send(() => engine.seekBar(bar));

  // The engine's playerState events are the truth; a failed command leaves
  // the state as the engine last reported it.
  Future<void> _send(Future<void> Function() command) async {
    try {
      await command();
    } on Object catch (e) {
      debugPrint('PlaybackCubit: $e');
    }
  }

  @override
  Future<void> close() async {
    hinge.removeListener(_onHingeChanged);
    await _settings.cancel();
    await _songs.cancel();
    await _events.cancel();
    return super.close();
  }
}
