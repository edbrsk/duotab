import 'dart:async';

import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/editor_cubit.dart';
import 'package:duoscore/features/score/score_cubit.dart';
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

  setUpAll(() {
    registerFallbackValue(const SetRest());
    registerFallbackValue(
      const ChordSpec(root: 0, type: 'maj', additions: [], bass: null),
    );
  });

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

  test('drawing another track clears the cursor, as the engine does', () async {
    await editor.command(Place(_at));
    expect(editor.state.position, _at);
    await score.selectTrack(2);
    await pumpEventQueue();
    expect(editor.state.position, isNull);
    expect(editor.state.chordName, isNull);
    expect(editor.state.canUndo, isTrue);
  });

  test('a failed command is reported', () async {
    when(() => engine.edit(any()))
        .thenThrow(const EngineException('no free MIDI channel'));
    final failures = <String>[];
    final sub = editor.failures.listen(failures.add);
    addTearDown(sub.cancel);
    await editor.addTrack(const [64, 59, 55, 50, 45, 40], 27);
    await pumpEventQueue();
    expect(failures, ['no free MIDI channel']);
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

  test("a tap doesn't place the cursor while playing only", () async {
    editor.placesOnTap = false;
    events.add(EngineEvent('tapped', {'position': _at.toJson()}));
    await pumpEventQueue();
    verifyNever(() => engine.edit(const Place(_at)));

    editor.placesOnTap = true;
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

  test('the title changes without a cursor', () async {
    await editor.setTitle('Riff');
    verify(() => engine.edit(const SetTitle('Riff'))).called(1);
  });

  test('the state follows the bar at the cursor', () async {
    when(() => engine.edit(any())).thenAnswer(
      (_) async => EditState(
        position: _at,
        issues: const [],
        canUndo: false,
        canRedo: false,
        song: drumsAndTwoGuitars,
        edited: false,
        barNumerator: 6,
        barDenominator: 8,
        barKey: 2,
        barMinor: true,
        barClef: 'bass',
        barTempo: 90,
        barTempoChange: true,
        canPaste: true,
      ),
    );
    await editor.command(const Place(_at));
    final state = editor.state;
    expect(
      [state.barNumerator, state.barDenominator, state.barKey, state.barMinor],
      [6, 8, 2, true],
    );
    expect(
      [state.barClef, state.barTempo, state.barTempoChange, state.canPaste],
      ['bass', 90, true, true],
    );
  });

  test('bar commands send their command', () async {
    await editor.command(const Place(_at));
    await editor.setTimeSignature(3, 4);
    await editor.setTempo(null);
    await editor.setKeySignature(-1, minor: false);
    await editor.setClef('bass');
    await editor.insertBar();
    await editor.deleteBar();
    await editor.copyBars();
    await editor.pasteBars();
    for (final command in const <EditCommand>[
      SetTimeSignature(3, 4),
      SetTempo(null),
      SetKeySignature(-1, minor: false),
      SetClef('bass'),
      InsertBar(),
      DeleteBar(),
      CopyBars(),
      PasteBars(),
    ]) {
      verify(() => engine.edit(command)).called(1);
    }
  });

  test('bar commands wait for a cursor', () async {
    await editor.setTimeSignature(3, 4);
    await editor.setTempo(100);
    await editor.setKeySignature(1, minor: false);
    await editor.setClef('treble');
    await editor.insertBar();
    await editor.deleteBar();
    await editor.copyBars();
    await editor.pasteBars();
    verifyNever(() => engine.edit(any()));
  });

  test('the state follows the structure at the cursor', () async {
    when(() => engine.edit(any())).thenAnswer(
      (_) async => EditState(
        position: _at,
        issues: const [],
        canUndo: false,
        canRedo: false,
        song: drumsAndTwoGuitars,
        edited: false,
        repeatStart: true,
        repeatCount: 2,
        endings: const [1],
        directions: const {'coda'},
      ),
    );
    await editor.command(const Place(_at));
    final state = editor.state;
    expect(
      [state.repeatStart, state.repeatCount, state.endings],
      [
        true,
        2,
        [1],
      ],
    );
    expect(state.directions, {'coda'});
  });

  test('structure commands send their command and wait for a cursor', () async {
    await editor.toggleRepeatStart();
    await editor.setRepeatEnd(2);
    await editor.toggleEnding(1);
    await editor.toggleDirection('segno');
    verifyNever(() => engine.edit(any()));
    await editor.command(const Place(_at));
    await editor.toggleRepeatStart();
    await editor.setRepeatEnd(2);
    await editor.toggleEnding(1);
    await editor.toggleDirection('segno');
    for (final command in const <EditCommand>[
      ToggleRepeatStart(),
      SetRepeatEnd(2),
      ToggleEnding(1),
      ToggleDirection('segno'),
    ]) {
      verify(() => engine.edit(command)).called(1);
    }
  });

  test(
    'track commands need no cursor, and the drawn track reaches the score',
    () async {
      when(() => engine.edit(any())).thenAnswer(
        (_) async => EditState(
          position: null,
          issues: const [],
          canUndo: true,
          canRedo: false,
          song: drumsAndTwoGuitars,
          edited: true,
          drawnTrack: 2,
        ),
      );
      await editor.addTrack(const [64, 59, 55, 50, 45, 40], 27);
      await editor.removeTrack(1);
      await editor.moveTrack(1, 0);
      await editor.renameTrack(0, 'Lead');
      for (final command in const <EditCommand>[
        AddTrack([64, 59, 55, 50, 45, 40], 27),
        RemoveTrack(1),
        MoveTrack(1, 0),
        RenameTrack(0, 'Lead'),
      ]) {
        verify(() => engine.edit(command)).called(1);
      }
      expect(score.state.selectedTrackIndex, 2);
    },
  );

  group('retune', () {
    const e = [64, 59, 55, 50, 45, 40];
    EditState reply({RetuneReport? retune}) => EditState(
      position: null,
      issues: const [],
      canUndo: true,
      canRedo: false,
      song: drumsAndTwoGuitars,
      edited: true,
      retune: retune,
    );
    RetuneReport report(int octave, {bool keepFrets = false}) => RetuneReport(
      track: 1,
      tuning: e,
      octave: octave,
      keepFrets: keepFrets,
      moved: 2,
      unplayable: 1,
    );

    setUp(() {
      when(() => engine.edit(any())).thenAnswer((invocation) async {
        final command = invocation.positionalArguments.single as EditCommand;
        return command is RetuneTrack
            ? reply(
                retune: report(command.octave, keepFrets: command.keepFrets),
              )
            : reply();
      });
      when(() => engine.undo()).thenAnswer((_) async => reply());
    });

    test(
      'retune sends the command without a cursor and keeps the report',
      () async {
        expect(editor.state.position, isNull);
        await editor.retune(1, e);
        verify(() => engine.edit(const RetuneTrack(1, e, 0))).called(1);
        expect(editor.state.retune!.moved, 2);
        expect(editor.state.retune!.unplayable, 1);
      },
    );

    test('octave reruns retune from the original song', () async {
      await editor.retune(1, e);

      await editor.retuneOctave(1);
      verifyInOrder([
        () => engine.undo(),
        () => engine.edit(const RetuneTrack(1, e, 1)),
      ]);
      expect(editor.state.retune!.octave, 1);

      await editor.retuneOctave(1);
      verify(() => engine.edit(const RetuneTrack(1, e, 2))).called(1);
      expect(editor.state.retune!.octave, 2);

      clearInteractions(engine);
      await editor.retuneOctave(1);
      verifyNever(() => engine.undo());
      verifyNever(() => engine.edit(any()));
    });

    test('keeping frets sends it, and takes no octave rerun', () async {
      await editor.retune(1, e, keepFrets: true);
      verify(() => engine.edit(const RetuneTrack(1, e, 0, keepFrets: true)))
          .called(1);
      clearInteractions(engine);
      await editor.retuneOctave(1);
      verifyNever(() => engine.undo());
      verifyNever(() => engine.edit(any()));
    });

    test('a double tap on an octave button reruns once', () async {
      await editor.retune(1, e);
      clearInteractions(engine);
      await Future.wait([editor.retuneOctave(1), editor.retuneOctave(1)]);
      verify(() => engine.undo()).called(1);
      verify(() => engine.edit(const RetuneTrack(1, e, 1))).called(1);
    });

    test('a failed undo stops the rerun', () async {
      await editor.retune(1, e);
      clearInteractions(engine);
      when(() => engine.undo()).thenThrow(const EngineException('busy'));
      await editor.retuneOctave(1);
      verifyNever(() => engine.edit(any()));
    });

    test('an edit without a report clears it', () async {
      await editor.retune(1, e);
      await editor.renameTrack(1, 'Lead');
      expect(editor.state.retune, isNull);
    });
  });

  group('chords', () {
    const cmaj7 = ChordSpec(root: 0, type: 'maj7', additions: [], bass: null);

    test("the editor carries the beat's chord", () async {
      when(() => engine.edit(any())).thenAnswer(
        (_) async => EditState(
          position: _at,
          issues: const [],
          canUndo: true,
          canRedo: false,
          song: SongSummary(title: 'T', tracks: drumsAndTwoGuitars.tracks),
          edited: true,
          chordName: 'Cmaj7',
          chordSpec: cmaj7,
          beatFrets: const [-1, 3, 2, 0, 0, 0],
        ),
      );
      await editor.command(const SetChord(cmaj7, [-1, 3, 2, 0, 0, 0]));
      expect(editor.state.chordName, 'Cmaj7');
      expect(editor.state.chordSpec, cmaj7);
      expect(editor.state.beatFrets, [-1, 3, 2, 0, 0, 0]);
    });

    test('chord positions need a cursor', () async {
      when(() => engine.chordPositions(any(), any())).thenAnswer(
        (_) async => const ChordPositions(name: 'Cmaj7', positions: []),
      );
      expect(await editor.chordPositions(cmaj7), isNull);
      verifyNever(() => engine.chordPositions(any(), any()));

      events.add(EngineEvent('tapped', {'position': _at.toJson()}));
      await pumpEventQueue();
      expect((await editor.chordPositions(cmaj7))!.name, 'Cmaj7');
      verify(() => engine.chordPositions(_at.track, cmaj7)).called(1);
    });
  });
}
