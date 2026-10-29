import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/duo/hinge_status_provider.dart';
import '../../engine/engine_bridge.dart';
import '../../engine/protocol.dart';

class PlaybackState {
  final bool playing;

  const PlaybackState({this.playing = false});

  PlaybackState copyWith({bool? playing}) =>
      PlaybackState(playing: playing ?? this.playing);
}

class PlaybackCubit extends Cubit<PlaybackState> {
  final EngineBridge engine;
  final HingeStatusProvider hinge;

  late final StreamSubscription<EngineEvent> _events;

  PlaybackCubit({required this.engine, required this.hinge})
    : super(const PlaybackState()) {
    _events = engine.events.listen(_onEngineEvent);
    hinge.addListener(_onHingeChanged);
  }

  void _onEngineEvent(EngineEvent event) {
    switch (event.type) {
      case 'playerState':
        emit(state.copyWith(playing: event.payload['playing'] == true));
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
    await _events.cancel();
    return super.close();
  }
}
