import 'dart:async';

import 'package:duotab/engine/engine_bridge.dart';
import 'package:duotab/engine/protocol.dart';
import 'package:duotab/features/editor/editor_cubit.dart';
import 'package:duotab/features/score/score_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../score/score_test_data.dart';

class _Engine extends Mock implements EngineBridge {}

const _at = EditPosition(track: 0, bar: 1, voice: 0, beat: 2, string: 3);

EditState _state({
  bool edited = true,
  String title = 'Edited',
  int duration = 4,
  int dots = 0,
}) => EditState(
  position: _at,
  beatDuration: duration,
  beatDots: dots,
  issues: const [BarIssue(bar: 1, voice: 0, ticksOff: -480)],
  canUndo: true,
  canRedo: false,
  song: SongSummary(title: title, tracks: drumsAndTwoGuitars.tracks),
  edited: edited,
);

void main() {
  late _Engine engine;
  late StreamController<EngineEvent> events;
  late ScoreCubit score;
  late EditorCubit editor;

  setUpAll(() => registerFallbackValue(const SetRest()));

  setUp(() async {
    engine = _Engine();
    events = StreamController<EngineEvent>.broadcast();
    when(() => engine.events).thenAnswer((_) => events.stream);
    when(() => engine.renderTrack(any())).thenAnswer((_) async {});
    when(() => engine.open(any())).thenAnswer((_) async => drumsAndTwoGuitars);
    // Like the engine, the reply tells the cursor beat's value after the command.
    when(() => engine.edit(any())).thenAnswer((invocation) async {
      final command = invocation.positionalArguments.single as EditCommand;
      return command is SetDuration
          ? _state(duration: command.duration, dots: command.dots)
          : _state();
    });
    score = ScoreCubit(engine: engine);
    editor = EditorCubit(engine: engine, score: score);
    await score.open('fixture.gp');
    await pumpEventQueue();
  });

  tearDown(() async {
    await editor.close();
    await score.close();
    await events.close();
  });

  test('a command updates position, issues and history flags', () async {
    await editor.command(const SetFret(5));
    expect(editor.state.position, _at);
    expect(editor.state.issues.single.ticksOff, -480);
    expect(editor.state.canUndo, isTrue);
    expect(editor.state.canRedo, isFalse);
  });

  test("an edited reply updates the score's song without a new open", () async {
    final openId = score.state.openId;
    await editor.command(const SetFret(5));
    expect(score.state.song!.title, 'Edited');
    expect(score.state.openId, openId);
  });

  test('a tap places the cursor', () async {
    events.add(EngineEvent('tapped', {'position': _at.toJson()}));
    await pumpEventQueue();
    verify(() => engine.edit(const Place(_at))).called(1);
  });

  test("choosing a note value changes the cursor's beat", () async {
    await editor.command(const SetFret(5));
    await editor.chooseDuration(8);
    expect(editor.state.duration, 8);
    verify(() => engine.edit(const SetDuration(8, 0))).called(1);
  });

  test('choosing dots keeps the note value', () async {
    await editor.command(const SetFret(5));
    await editor.chooseDuration(8);
    await editor.chooseDots(1);
    verify(() => engine.edit(const SetDuration(8, 1))).called(1);
  });

  test('without a cursor, choices are only remembered', () async {
    await editor.chooseDuration(16);
    expect(editor.state.duration, 16);
    verifyNever(() => engine.edit(any()));
  });

  test('edited fires only for edits that change the song', () async {
    var fired = 0;
    final sub = editor.edited.listen((_) => fired++);
    when(() => engine.edit(const Move('right')))
        .thenAnswer((_) async => _state(edited: false));
    await editor.command(const Move('right'));
    await pumpEventQueue();
    expect(fired, 0);
    await editor.command(const SetFret(5));
    await pumpEventQueue();
    expect(fired, 1);
    await sub.cancel();
  });

  test('undo and redo update the state', () async {
    when(() => engine.undo()).thenAnswer((_) async => _state(title: 'Undone'));
    when(() => engine.redo()).thenAnswer((_) async => _state(title: 'Redone'));
    await editor.undo();
    expect(score.state.song!.title, 'Undone');
    await editor.redo();
    expect(score.state.song!.title, 'Redone');
  });

  test('opening a song clears the cursor', () async {
    await editor.command(const SetFret(5));
    await score.open('fixture.gp');
    await pumpEventQueue();
    expect(editor.state.position, isNull);
    expect(editor.state.canUndo, isFalse);
    expect(editor.state.issues, isEmpty);
  });

  test('a failed command keeps the state', () async {
    when(() => editor.engine.edit(const SetFret(30)))
        .thenThrow(const EngineException('fret 30 out of range'));
    await editor.command(const SetFret(30));
    expect(editor.state.position, isNull);
  });

  test("the note value follows the cursor beat's", () async {
    when(() => engine.edit(any()))
        .thenAnswer((_) async => _state(edited: false, duration: 1, dots: 1));
    await editor.command(const Place(_at));
    expect(editor.state.duration, 1);
    expect(editor.state.dots, 1);
  });

  test('a reply for a song no longer open is ignored', () async {
    final reply = Completer<EditState>();
    when(() => engine.edit(any())).thenAnswer((_) => reply.future);
    final command = editor.command(const SetFret(5));
    await score.open('fixture.gp');
    reply.complete(_state(title: 'Old song'));
    await command;
    expect(editor.state.position, isNull);
    expect(score.state.song!.title, isNot('Old song'));
  });

  test('the state follows the techniques at the cursor', () async {
    when(() => engine.edit(any())).thenAnswer(
      (_) async => EditState(
        position: _at,
        issues: const [],
        canUndo: false,
        canRedo: false,
        song: drumsAndTwoGuitars,
        edited: false,
        techniques: const {'bend'},
        dynamicMark: 'mf',
        tuplet: 3,
        hasNote: true,
        bendKind: 'prebend',
        bendAmount: 8,
      ),
    );
    await editor.command(const Place(_at));
    expect(editor.state.bendKind, 'prebend');
    expect(editor.state.bendAmount, 8);
    expect(editor.state.techniques, {'bend'});
    expect(editor.state.dynamicMark, 'mf');
    expect(editor.state.tuplet, 3);
    expect(editor.state.hasNote, isTrue);
  });

  test('toggle sends the technique', () async {
    await editor.command(const Place(_at));
    await editor.toggle('slide');
    verify(() => engine.edit(const Toggle('slide'))).called(1);
    await editor.setDynamic('ff');
    verify(() => engine.edit(const SetDynamic('ff'))).called(1);
    await editor.setTuplet(5);
    verify(() => engine.edit(const SetTuplet(5))).called(1);
    await editor.addGrace();
    verify(() => engine.edit(const AddGrace())).called(1);
    await editor.setBend('bend', 2);
    verify(() => engine.edit(const SetBend('bend', 2))).called(1);
  });

  test('technique commands wait for a cursor', () async {
    await editor.toggle('slide');
    await editor.setDynamic('ff');
    await editor.setTuplet(3);
    await editor.addGrace();
    await editor.setBend('bend', 4);
    verifyNever(() => engine.edit(any()));
  });
}
