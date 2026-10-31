import 'dart:async';

import 'package:duoscore/core/duo/fold_orientation.dart';
import 'package:duoscore/core/duo/hinge_status_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<dynamic> hingeEvents;
  late HingeStatusProvider hinge;
  late List<List<DeviceOrientation>> calls;
  late void Function() stop;

  setUp(() {
    hingeEvents = StreamController<dynamic>();
    hinge = HingeStatusProvider(hingeEvents: hingeEvents.stream);
    calls = [];
    stop = portraitWhileFolded(hinge, (orientations) async {
      calls.add(orientations);
    });
  });

  tearDown(() async {
    stop();
    hinge.dispose();
    await hingeEvents.close();
  });

  Future<void> send(String status) async {
    hingeEvents.add(status);
    await pumpEventQueue();
  }

  test('folded, only portrait; open, any orientation', () async {
    await send('closed');
    await send('partiallyOpen');
    await send('fullyOpen');
    await send('closed');

    expect(calls, [
      [DeviceOrientation.portraitUp],
      <DeviceOrientation>[],
      [DeviceOrientation.portraitUp],
    ]);
  });

  test('an open or unknown hinge leaves orientation alone', () async {
    await send('fullyOpen');
    await send('unavailable');

    expect(calls, isEmpty);
  });

  test('stops following the hinge once stopped', () async {
    stop();
    await send('closed');

    expect(calls, isEmpty);
  });
}
