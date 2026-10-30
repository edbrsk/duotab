import 'package:bloc_test/bloc_test.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/playback/levels.dart';
import 'package:duoscore/features/playback/mix_level.dart';
import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/score/mixer_row.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Playback extends MockCubit<PlaybackState> implements PlaybackCubit {}

const _guitar = TrackSummary(
  index: 0,
  name: 'Guitar 1',
  kind: TrackKind.guitar,
  stringCount: 6,
  tuning: [64, 59, 55, 50, 45, 40],
  midiProgram: 29,
);

void main() {
  late _Playback playback;
  late ValueNotifier<Levels?> levels;

  setUp(() {
    playback = _Playback();
    levels = ValueNotifier(null);
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.levels).thenReturn(levels);
    when(() => playback.setVolumeDb(any(), any(), save: any(named: 'save')))
        .thenAnswer((_) async {});
    when(() => playback.setPan(any(), any(), save: any(named: 'save')))
        .thenAnswer((_) async {});
    when(() => playback.setMasterDb(any(), save: any(named: 'save')))
        .thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, Widget row) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<PlaybackCubit>.value(
          value: playback,
          child: Center(child: SizedBox(width: 440, child: row)),
        ),
      ),
    ),
  );

  testWidgets('shows the level in dB', (tester) async {
    await pump(tester, const MixerRow(track: _guitar, volumeDb: -6, pan: 0));
    expect(find.text('−6.0 dB'), findsOneWidget);
  });

  testWidgets(
    'dragging the fader moves in half decibels and saves on release',
    (tester) async {
      await pump(tester, const MixerRow(track: _guitar, volumeDb: 0, pan: 0));
      await tester.drag(
        find.byKey(const ValueKey('fader-0')),
        const Offset(-40, 0),
      );
      await tester.pump(kDoubleTapTimeout);
      final previews = verify(
        () => playback.setVolumeDb(0, captureAny(), save: false),
      ).captured.cast<double>();
      expect(previews, isNotEmpty);
      expect(
        previews.every((db) => (db * 2) == (db * 2).roundToDouble()),
        isTrue,
      );
      verify(() => playback.setVolumeDb(0, any())).called(1);
    },
  );

  testWidgets('double-tapping the fader returns it to 0 dB', (tester) async {
    await pump(tester, const MixerRow(track: _guitar, volumeDb: -6, pan: 0));
    final fader = find.byKey(const ValueKey('fader-0'));
    await tester.tap(fader);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(fader);
    await tester.pumpAndSettle();
    verify(() => playback.setVolumeDb(0, 0)).called(1);
  });

  testWidgets('turning the knob shows its side, and double-tap centres it', (
    tester,
  ) async {
    await pump(tester, const MixerRow(track: _guitar, volumeDb: 0, pan: 0));
    final knob = find.byKey(const ValueKey('pan-0'));
    final side = find.textContaining(RegExp(r'^R\d+$'));
    final gesture = await tester.startGesture(tester.getCenter(knob));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    expect(side, findsOneWidget);
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    expect(side, findsNothing);
    verify(() => playback.setPan(0, any(that: greaterThan(0)), save: false))
        .called(greaterThan(0));
    verify(() => playback.setPan(0, any(that: greaterThan(0)))).called(1);
    await tester.tap(knob);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(knob);
    await tester.pumpAndSettle();
    verify(() => playback.setPan(0, 0)).called(1);
  });

  testWidgets('after a turn, the knob draws the pan it is given', (
    tester,
  ) async {
    await pump(tester, const MixerRow(track: _guitar, volumeDb: 0, pan: 0));
    final knob = find.byKey(const ValueKey('pan-0'));
    final gesture = await tester.startGesture(tester.getCenter(knob));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    final paint = tester.widget<CustomPaint>(
      find.descendant(of: knob, matching: find.byType(CustomPaint)),
    );
    // The row was built with pan 0, which the cubit would have changed.
    expect((paint.painter! as dynamic).pan, 0);
  });

  testWidgets('the meter follows the levels', (tester) async {
    await pump(tester, const MixerRow(track: _guitar, volumeDb: 0, pan: 0));
    levels.value = const Levels(tracks: [MeterLevel(-12, -20)]);
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const ValueKey('meter-0')),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter! as MeterPainter;
    expect(painter.leftFraction, closeTo(faderPosition(-12), 0.001));
    expect(painter.rightFraction, closeTo(faderPosition(-20), 0.001));
  });

  testWidgets('semantics read the level', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const MixerRow(track: _guitar, volumeDb: -6, pan: 0));
    expect(
      find.bySemanticsLabel('Volume of Guitar 1: −6.0 dB'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the master fader sets the master level', (tester) async {
    await pump(tester, const MasterRow(volumeDb: -6));
    expect(find.text('−6.0 dB'), findsOneWidget);
    final fader = find.byKey(const ValueKey('fader-master'));
    await tester.tap(fader);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(fader);
    await tester.pumpAndSettle();
    verify(() => playback.setMasterDb(0)).called(1);
  });
}
