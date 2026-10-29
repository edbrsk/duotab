import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/duo/hinge_status_provider.dart';
import '../../engine/engine_bridge.dart';
import '../../engine/protocol.dart';
import '../score/score_cubit.dart';

class PlaybackState {
  final bool playing;

  /// The bar under the playback position.
  final int bar;

  const PlaybackState({this.playing = false, this.bar = 0});

  PlaybackState copyWith({bool? playing, int? bar}) =>
      PlaybackState(playing: playing ?? this.playing, bar: bar ?? this.bar);
}

class PlaybackCubit extends Cubit<PlaybackState> {
  final EngineBridge engine;
  final HingeStatusProvider hinge;
  final ScoreCubit score;

  late final StreamSubscription<EngineEvent> _events;
  late final StreamSubscription<ScoreState> _songs;
  SongSummary? _song;

  PlaybackCubit({
    required this.engine,
    required this.hinge,
    required this.score,
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
  }

  void _onEngineEvent(EngineEvent event) {
    switch (event.type) {
      case 'playerState':
        emit(state.copyWith(playing: event.payload['playing'] == true));
      case 'position':
        emit(state.copyWith(bar: event.payload['bar'] as int));
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
