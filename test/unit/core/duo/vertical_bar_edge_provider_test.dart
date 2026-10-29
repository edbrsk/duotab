import 'dart:async';

import 'package:duotab/core/duo/vertical_bar_edge_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerticalBarEdgeProvider', () {
    late StreamController<dynamic> events;
    late VerticalBarEdgeProvider provider;

    setUp(() {
      events = StreamController<dynamic>();
      provider = VerticalBarEdgeProvider(edgeEvents: events.stream);
    });

    tearDown(() async {
      provider.dispose();
      await events.close();
    });

    test(
      'follows the edge reported by the platform as the device folds',
      () async {
        final seen = <VerticalBarEdge>[];
        provider.addListener(() => seen.add(provider.edge));

        events
          ..add('trailing')
          ..add('leading')
          ..add('unspecified');
        await pumpEventQueue();

        expect(seen, [
          VerticalBarEdge.trailing,
          VerticalBarEdge.leading,
          VerticalBarEdge.unspecified,
        ]);
      },
    );

    test('does not notify when the edge is unchanged', () async {
      var notifications = 0;
      provider.addListener(() => notifications++);

      events
        ..add('trailing')
        ..add('trailing');
      await pumpEventQueue();

      expect(notifications, 1);
    });

    test(
      'treats unknown values and stream errors as no vertical bar',
      () async {
        events
          ..add('trailing')
          ..add('top')
          ..addError(Exception('channel failed'));
        await pumpEventQueue();

        expect(provider.edge, VerticalBarEdge.unspecified);
      },
    );
  });
}
