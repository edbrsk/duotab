import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/engine_bridge.dart';
import '../../engine/protocol.dart';
import '../score/score_cubit.dart';

class EditorState {
  /// Null until the owner taps a string of the open song.
  final EditPosition? position;
  final List<BarIssue> issues;
  final bool canUndo;
  final bool canRedo;

  /// The note value and dots chosen in the palette, as alphaTab durations.
  final int duration;
  final int dots;

  const EditorState({
    this.position,
    this.issues = const [],
    this.canUndo = false,
    this.canRedo = false,
    this.duration = 4,
    this.dots = 0,
  });

  EditorState copyWith({int? duration, int? dots}) => EditorState(
    position: position,
    issues: issues,
    canUndo: canUndo,
    canRedo: canRedo,
    duration: duration ?? this.duration,
    dots: dots ?? this.dots,
  );
}

class EditorCubit extends Cubit<EditorState> {
  final EngineBridge engine;
  final ScoreCubit score;

  late final StreamSubscription<EngineEvent> _events;
  late final StreamSubscription<ScoreState> _songs;
  final _edited = StreamController<void>.broadcast();
  int? _openId;

  EditorCubit({required this.engine, required this.score})
    : super(const EditorState()) {
    _openId = score.state.openId;
    _events = engine.events.listen((event) {
      if (event.type == 'tapped') {
        final position = EditPosition.fromJson(
          event.payload['position'] as Map<String, dynamic>,
        );
        unawaited(command(Place(position)));
      }
    });
    _songs = score.stream.listen((scoreState) {
      if (scoreState.openId == _openId) return;
      _openId = scoreState.openId;
      emit(EditorState(duration: state.duration, dots: state.dots));
    });
  }

  /// Fires after each change to the song, for saving.
  Stream<void> get edited => _edited.stream;

  Future<void> command(EditCommand command) =>
      _apply(() => engine.edit(command));

  Future<void> undo() => _apply(engine.undo);

  Future<void> redo() => _apply(engine.redo);

  Future<void> chooseDuration(int duration) async {
    emit(state.copyWith(duration: duration));
    if (state.position != null) {
      await command(SetDuration(duration, state.dots));
    }
  }

  Future<void> chooseDots(int dots) async {
    emit(state.copyWith(dots: dots));
    if (state.position != null) {
      await command(SetDuration(state.duration, dots));
    }
  }

  Future<void> _apply(Future<EditState> Function() request) async {
    final EditState reply;
    try {
      reply = await request();
    } on Object catch (e) {
      debugPrint('EditorCubit: $e');
      return;
    }
    emit(
      EditorState(
        position: reply.position,
        issues: reply.issues,
        canUndo: reply.canUndo,
        canRedo: reply.canRedo,
        duration: state.duration,
        dots: state.dots,
      ),
    );
    if (reply.edited) {
      score.applyEdit(reply.song);
      _edited.add(null);
    }
  }

  @override
  Future<void> close() async {
    await _events.cancel();
    await _songs.cancel();
    await _edited.close();
    return super.close();
  }
}
