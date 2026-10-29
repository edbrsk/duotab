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

  /// The note value and dots of the beat under the cursor, or the ones last
  /// chosen in the palette, as alphaTab durations.
  final int duration;
  final int dots;

  /// At the cursor, as in [EditState].
  final Set<String> techniques;
  final String? dynamicMark;
  final int tuplet;
  final bool hasNote;

  const EditorState({
    this.position,
    this.issues = const [],
    this.canUndo = false,
    this.canRedo = false,
    this.duration = 4,
    this.dots = 0,
    this.techniques = const {},
    this.dynamicMark,
    this.tuplet = 1,
    this.hasNote = false,
  });

  EditorState copyWith({int? duration, int? dots}) => EditorState(
    position: position,
    issues: issues,
    canUndo: canUndo,
    canRedo: canRedo,
    duration: duration ?? this.duration,
    dots: dots ?? this.dots,
    techniques: techniques,
    dynamicMark: dynamicMark,
    tuplet: tuplet,
    hasNote: hasNote,
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

  Future<void> toggle(String technique) => _atCursor(Toggle(technique));

  Future<void> setDynamic(String mark) => _atCursor(SetDynamic(mark));

  Future<void> setTuplet(int tuplet) => _atCursor(SetTuplet(tuplet));

  Future<void> addGrace() => _atCursor(const AddGrace());

  Future<void> _atCursor(EditCommand edit) async {
    if (state.position != null) await command(edit);
  }

  Future<void> _apply(Future<EditState> Function() request) async {
    final openId = _openId;
    final EditState reply;
    try {
      reply = await request();
    } on Object catch (e) {
      debugPrint('EditorCubit: $e');
      return;
    }
    // A reply that arrives after another song opened belongs to the old one.
    if (openId != _openId || isClosed) return;
    emit(
      EditorState(
        position: reply.position,
        issues: reply.issues,
        canUndo: reply.canUndo,
        canRedo: reply.canRedo,
        duration: reply.beatDuration ?? state.duration,
        dots: reply.beatDots ?? state.dots,
        techniques: reply.techniques,
        dynamicMark: reply.dynamicMark,
        tuplet: reply.tuplet,
        hasNote: reply.hasNote,
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
