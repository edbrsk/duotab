import 'dart:async';

import 'package:duotab/core/duo/hinge_status_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HingeStatusProvider', () {
    late StreamController<dynamic> events;
    late HingeStatusProvider provider;

    setUp(() {
      events = StreamController<dynamic>();
      provider = HingeStatusProvider(hingeEvents: events.stream);
    });

    tearDown(() async {
      provider.dispose();
      await events.close();
    });

    test('is closed only when the hinge reports closed', () async {
      final seen = <bool>[];
      provider.addListener(() => seen.add(provider.isOpen));

      events
        ..add('fullyOpen')
        ..add('closed')
        ..add('partiallyOpen');
      await pumpEventQueue();

      expect(seen, [true, false, true]);
    });

    test(
      'treats unknown, unavailable, unrecognised values and errors as open',
      () async {
        events
          ..add('closed')
          ..add('unavailable');
        await pumpEventQueue();
        expect(provider.isOpen, isTrue);

        events
          ..add('closed')
          ..add('sideways');
        await pumpEventQueue();
        expect(provider.status, HingeStatus.unknown);

        events
          ..add('closed')
          ..addError(Exception('channel failed'));
        await pumpEventQueue();
        expect(provider.isOpen, isTrue);
      },
    );

    test('does not notify when the status is unchanged', () async {
      var notifications = 0;
      provider.addListener(() => notifications++);

      events
        ..add('closed')
        ..add('closed');
      await pumpEventQueue();

      expect(notifications, 1);
    });
  });
}
