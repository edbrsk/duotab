import 'dart:async';

import 'package:duoscore/features/playback/playback_cubit.dart';
import 'package:duoscore/features/playback/screen_awake.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the screen stays awake only while playing', () async {
    final states = StreamController<PlaybackState>();
    addTearDown(states.close);
    final calls = <bool>[];
    final subscription = keepAwakeWhilePlaying(states.stream, ({
      required awake,
    }) async {
      calls.add(awake);
    });
    addTearDown(subscription.cancel);

    states
      ..add(const PlaybackState())
      ..add(const PlaybackState(playing: true))
      ..add(const PlaybackState(playing: true, bar: 3))
      ..add(const PlaybackState());
    await pumpEventQueue();

    expect(calls, [true, false]);
  });

  test("a failed call doesn't stop the next one", () async {
    final states = StreamController<PlaybackState>();
    addTearDown(states.close);
    final calls = <bool>[];
    final subscription = keepAwakeWhilePlaying(states.stream, ({
      required awake,
    }) async {
      calls.add(awake);
      if (calls.length == 1) throw StateError('no channel');
    });
    addTearDown(subscription.cancel);

    states
      ..add(const PlaybackState(playing: true))
      ..add(const PlaybackState());
    await pumpEventQueue();

    expect(calls, [true, false]);
  });
}
