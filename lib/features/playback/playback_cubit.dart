import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/duo/hinge_status_provider.dart';
import '../../engine/engine_bridge.dart';
import '../../engine/protocol.dart';
import '../score/score_cubit.dart';
import '../settings/settings_cubit.dart';
import 'levels.dart';
import 'mix_level.dart';
import 'practice_moves.dart';
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

  /// Outside the state: meters change many times a second, and only they redraw.
  final _levels = ValueNotifier<Levels?>(null);
  ValueListenable<Levels?> get levels => _levels;
  late final StreamSubscription<ScoreState> _songs;
  late final StreamSubscription<AppSettings> _settings;
  StreamSubscription<Duration>? _latencies;
  var _metersOn = false;
  bool _hingeWasOpen;
  Duration? _outputLatency;
  SongSummary? _song;

  /// Practice of tracks removed from the open song, by channel, for undo.
  final _parked = <String, TrackPractice>{};
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
    Stream<Duration>? outputLatency,
  }) : _hingeWasOpen = hinge.isOpen,
       super(const PlaybackState()) {
    _events = engine.events.listen(_onEngineEvent);
    _latencies = outputLatency?.listen((latency) {
      _outputLatency = latency;
      unawaited(_send(() => engine.setOutputLatency(latency)));
    });
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
      final before = _song;
      _song = song;
      if (_practiceReady && before != null && _tracksMoved(before, song)) {
        unawaited(_followTracks(before, song));
      }
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
    _parked.clear();
    emit(
      state.copyWith(
        playing: false,
        bar: 0,
        practice: const PracticeSettings(),
      ),
    );
    unawaited(_applyPractice(song, scoreState.path!));
  }

  static bool _tracksMoved(SongSummary before, SongSummary after) =>
      before.tracks.length != after.tracks.length ||
      [
        for (final (i, t) in before.tracks.indexed)
          t.channel != after.tracks[i].channel,
      ].any((changed) => changed);

  /// After tracks were added, removed or moved: each keeps its practice.
  Future<void> _followTracks(SongSummary before, SongSummary after) async {
    final moved = movePractice(
      before,
      after,
      state.practice.tracks,
      parked: _parked,
    );
    final resolved = resolvePractice(
      after,
      state.practice.copyWith(tracks: moved),
      settings.state.defaultTone,
    );
    await _updatePractice(resolved);
    await _send(
      () => engine.setTracks([for (final t in after.tracks) _mix(t)]),
    );
    await _send(
      () => engine.setStaves([
        for (final t in after.tracks)
          if (resolved.tracks[t.index] case final p?) p.staves(t.index),
      ]),
    );
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
        if (resolved.tracks[t.index] case final p? when !p.drawsDefaultStaves)
          p.staves(t.index),
    ];
    for (final command in [
      () => engine.setTracks([for (final t in song.tracks) _mix(t)]),
      () => engine.setMaster(resolved.masterDb ?? song.masterDb),
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
    final value = (speed.clamp(minSpeed, maxSpeed) * 20).round() / 20;
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
      volumeDb: p.volumeDb ?? snapDb(track.volumeDb),
      pan: p.pan ?? track.pan,
    );
  }

  /// [save] false while a fader moves: the level is heard, and saved on release.
  Future<void> setVolumeDb(int track, double db, {bool save = true}) =>
      _updateTrack(track, (p) => p.copyWith(volumeDb: db), save: save);

  /// [save] false while a knob turns.
  Future<void> setPan(int track, double pan, {bool save = true}) =>
      _updateTrack(track, (p) => p.copyWith(pan: pan.clamp(-1, 1)), save: save);

  /// [save] false while the master fader moves.
  Future<void> setMasterDb(double db, {bool save = true}) async {
    if (!_practiceReady) return;
    final practice = state.practice.copyWith(masterDb: db);
    await Future.wait([
      if (save) _updatePractice(practice) else _show(practice),
      _send(() => engine.setMaster(db)),
    ]);
  }

  Future<void> setMute(int track, {required bool on}) =>
      _updateTrack(track, (p) => p.copyWith(mute: on));

  Future<void> setSolo(int track, {required bool on}) =>
      _updateTrack(track, (p) => p.copyWith(solo: on));

  Future<void> setTone(int track, Tone tone) =>
      _updateTrack(track, (p) => p.copyWith(tone: tone, toneChosen: true));

  Future<void> setStaffView(
    int track, {
    required bool notation,
    required bool tab,
    required bool slash,
    required bool numbered,
  }) async {
    final song = _song;
    if (!_practiceReady || song == null || track >= song.tracks.length) return;
    // The cursor and taps work on the standard and tab staves.
    if (!notation && !tab) return;
    final tracks = {...state.practice.tracks};
    final changed = (tracks[track] ?? const TrackPractice()).copyWith(
      showNotation: notation,
      showTab: tab,
      showSlash: slash,
      showNumbered: numbered,
    );
    tracks[track] = changed;
    await Future.wait([
      _updatePractice(state.practice.copyWith(tracks: tracks)),
      _send(() => engine.setStaves([changed.staves(track)])),
    ]);
  }

  Future<void> _updateTrack(
    int index,
    TrackPractice Function(TrackPractice) change, {
    bool save = true,
  }) async {
    final song = _song;
    if (!_practiceReady || song == null || index >= song.tracks.length) return;
    final tracks = {...state.practice.tracks};
    tracks[index] = change(tracks[index] ?? const TrackPractice());
    final practice = state.practice.copyWith(tracks: tracks);
    await Future.wait([
      if (save) _updatePractice(practice) else _show(practice),
      _send(() => engine.setTracks([_mix(song.tracks[index])])),
    ]);
  }

  Future<void> _show(PracticeSettings practice) async =>
      emit(state.copyWith(practice: practice));

  Future<void> showMeters({required bool on}) {
    _metersOn = on;
    return _send(() => engine.setMeters(on: on));
  }

  void _onEngineEvent(EngineEvent event) {
    switch (event.type) {
      case 'playerState':
        emit(state.copyWith(playing: event.payload['playing'] == true));
      case 'position':
        emit(state.copyWith(bar: event.payload['bar'] as int));
      case 'levels':
        _levels.value = Levels.fromJson(event.payload);
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
        // Its meters start off, with no latency.
        if (_metersOn) unawaited(_send(() => engine.setMeters(on: true)));
        if (_outputLatency case final latency?) {
          unawaited(_send(() => engine.setOutputLatency(latency)));
        }
    }
  }

  // Both ways the sheet is drawn again at a new width.
  void _onHingeChanged() {
    if (hinge.isOpen == _hingeWasOpen) return;
    _hingeWasOpen = hinge.isOpen;
    unawaited(pause());
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
    if (!isClosed) _levels.dispose();
    hinge.removeListener(_onHingeChanged);
    await _settings.cancel();
    await _latencies?.cancel();
    await _songs.cancel();
    await _events.cancel();
    return super.close();
  }
}
