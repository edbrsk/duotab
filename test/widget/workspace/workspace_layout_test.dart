import 'dart:async';

import 'package:duotab/core/duo/vertical_bar_edge_provider.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:duotab/presentation/workspace/workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late StreamController<dynamic> edgeEvents;
  late VerticalBarEdgeProvider edge;

  setUp(() {
    edgeEvents = StreamController<dynamic>();
    edge = VerticalBarEdgeProvider(edgeEvents: edgeEvents.stream);
  });

  tearDown(() async {
    edge.dispose();
    await edgeEvents.close();
  });

  Future<void> pumpLayout(
    WidgetTester tester, {
    required double width,
    required String barEdge,
    double left = 0,
    double right = 0,
    Widget trackPanel = const Text('track content'),
  }) async {
    tester.view
      ..physicalSize = Size(width, 626)
      ..devicePixelRatio = 1
      ..padding = FakeViewPadding(left: left, right: right);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: edge,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkspaceLayout(
            palette: const Text('palette content'),
            score: const Text('score content'),
            trackPanel: trackPanel,
          ),
        ),
      ),
    );
    edgeEvents.add(barEdge);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('centres the score on the full screen with a trailing bar', (
    tester,
  ) async {
    await pumpLayout(tester, width: 890, barEdge: 'trailing', right: 46);

    final score = tester.getRect(find.byKey(const Key('score')));
    expect(score.left, 220);
    expect(score.right, 670);
    expect(score.center.dx, 445);
    final panelContent = tester.getRect(find.byKey(const Key('trackPanel')));
    expect(panelContent.right, lessThanOrEqualTo(890 - 46));
  });

  testWidgets('mirrors when the bar is on the leading edge', (tester) async {
    await pumpLayout(tester, width: 890, barEdge: 'leading', left: 46);

    final palette = tester.getRect(find.byKey(const Key('palette')));
    expect(palette.left, greaterThanOrEqualTo(46));
    expect(tester.getRect(find.byKey(const Key('score'))).center.dx, 445);
  });

  testWidgets('panel content does not inset the vertical bar a second time', (
    tester,
  ) async {
    // The iPhone Duo inner display in landscape, as measured on the simulator.
    tester.view.physicalSize = const Size(951, 669);
    await pumpLayout(
      tester,
      width: 951,
      barEdge: 'trailing',
      right: 84,
      trackPanel: const Material(child: ListTile(title: Text('Guitar 1'))),
    );

    // Applied twice, the 84 pt inset leaves the name about 4 pt wide.
    expect(tester.getSize(find.text('Guitar 1')).width, greaterThan(40));
    expect(
      tester.getSize(find.byType(ListTile)).width,
      tester.getSize(find.byKey(const Key('trackPanel'))).width,
    );
  });

  testWidgets('collapses to the score below the three-column width', (
    tester,
  ) async {
    await pumpLayout(tester, width: 600, barEdge: 'unspecified');

    expect(find.byKey(const Key('palette')), findsNothing);
    expect(find.text('Make DuoTab wider to edit'), findsOneWidget);
    expect(find.text('score content'), findsOneWidget);
  });
}
