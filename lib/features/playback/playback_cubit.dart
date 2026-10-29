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
  SongSummary? _song;

  PlaybackCubit({
    required this.engine,
    required this.hinge,
    required this.score,
    required this.practice,
    required this.settings,
  }) : super(const PlaybackState()) {
    _events = engine.events.listen(_onEngineEvent);
    _songs = score.stream.listen(_onScoreChanged);
    hinge.addListener(_onHingeChanged);
  }

  // A new song object means the engine loaded a song, even the same file
  // again after a restart; the engine's player starts over at bar 0.
  void _onScoreChanged(ScoreState scoreState) {
    final song = scoreState.song;
    if (song == null || identical(song, _song)) return;
    _song = song;
    emit(state.copyWith(playing: false, bar: 0));
    unawaited(_applyPractice(song, scoreState.path!));
  }

  Future<void> _applyPractice(SongSummary song, String path) async {
    final resolved = resolvePractice(
      song,
      await practice.load(path),
      settings.state.defaultTone,
    );
    if (!identical(song, _song)) return;
    emit(state.copyWith(practice: resolved));
    await _send(() => engine.setTracks([for (final t in song.tracks) _mix(t)]));
    await _send(() => engine.setSpeed(resolved.speed));
    await _send(() => engine.setLooping(looping: resolved.looping));
    await _send(() => engine.setRange(resolved.range));
  }

  Future<void> setSpeed(double speed) async {
    // 5% steps; dividing a whole number of steps gives the exact literal.
    final value = (speed.clamp(0.25, 1.5) * 20).round() / 20;
    await Future.wait([
      _updatePractice(state.practice.copyWith(speed: value)),
      _send(() => engine.setSpeed(value)),
    ]);
  }

  Future<void> setLooping({required bool on}) => Future.wait([
    _updatePractice(state.practice.copyWith(looping: on)),
    _send(() => engine.setLooping(looping: on)),
  ]);

  Future<void> _updatePractice(PracticeSettings settings) async {
    final path = score.state.path;
    if (_song == null || path == null) return;
    emit(state.copyWith(practice: settings));
    await practice.save(path, settings);
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

  Future<void> _updateTrack(
    int index,
    TrackPractice Function(TrackPractice) change,
  ) async {
    final song = _song;
    final path = score.state.path;
    if (song == null || path == null || index >= song.tracks.length) return;
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
    await _songs.cancel();
    await _events.cancel();
    return super.close();
  }
}
