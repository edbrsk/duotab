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
  final String? bendKind;
  final int bendAmount;
  final int barNumerator;
  final int barDenominator;
  final int barKey;
  final bool barMinor;
  final String? barClef;
  final int barTempo;
  final bool barTempoChange;
  final bool canPaste;

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
    this.bendKind,
    this.bendAmount = 4,
    this.barNumerator = 4,
    this.barDenominator = 4,
    this.barKey = 0,
    this.barMinor = false,
    this.barClef,
    this.barTempo = 120,
    this.barTempoChange = false,
    this.canPaste = false,
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
    bendKind: bendKind,
    bendAmount: bendAmount,
    barNumerator: barNumerator,
    barDenominator: barDenominator,
    barKey: barKey,
    barMinor: barMinor,
    barClef: barClef,
    barTempo: barTempo,
    barTempoChange: barTempoChange,
    canPaste: canPaste,
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

  /// A null [kind] removes the bend.
  Future<void> setBend(String? kind, int amount) =>
      _atCursor(SetBend(kind, amount));

  Future<void> setTimeSignature(int numerator, int denominator) =>
      _atCursor(SetTimeSignature(numerator, denominator));

  /// Null removes the bar's tempo marking.
  Future<void> setTempo(int? bpm) => _atCursor(SetTempo(bpm));

  Future<void> setKeySignature(int key, {required bool minor}) =>
      _atCursor(SetKeySignature(key, minor: minor));

  Future<void> setClef(String clef) => _atCursor(SetClef(clef));

  Future<void> insertBar() => _atCursor(const InsertBar());

  Future<void> deleteBar() => _atCursor(const DeleteBar());

  Future<void> copyBars() => _atCursor(const CopyBars());

  Future<void> pasteBars() => _atCursor(const PasteBars());

  Future<void> setTitle(String title) => command(SetTitle(title));

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
        bendKind: reply.bendKind,
        bendAmount: reply.bendAmount,
        barNumerator: reply.barNumerator,
        barDenominator: reply.barDenominator,
        barKey: reply.barKey,
        barMinor: reply.barMinor,
        barClef: reply.barClef,
        barTempo: reply.barTempo,
        barTempoChange: reply.barTempoChange,
        canPaste: reply.canPaste,
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
