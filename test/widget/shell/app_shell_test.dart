import 'dart:async';

import 'package:duoscore/core/duo/vertical_bar_edge_provider.dart';
import 'package:duoscore/l10n/app_localizations.dart';
import 'package:duoscore/presentation/shell/app_destinations.dart';
import 'package:duoscore/presentation/shell/app_shell.dart';
import 'package:duoscore/presentation/shell/navigation_cubit.dart';
import 'package:duoscore/presentation/widgets/app_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _count = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('count: $_count'),
    ),
  );
}

void main() {
  late StreamController<dynamic> edgeEvents;
  late VerticalBarEdgeProvider edge;
  late NavigationCubit navigation;

  setUp(() {
    edgeEvents = StreamController<dynamic>();
    edge = VerticalBarEdgeProvider(edgeEvents: edgeEvents.stream);
    navigation = NavigationCubit();
  });

  tearDown(() async {
    edge.dispose();
    await navigation.close();
    await edgeEvents.close();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required String barEdge,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    tester.view
      ..physicalSize = const Size(890, 626)
      ..devicePixelRatio = 1
      ..padding = FakeViewPadding(
        left: padding.left,
        right: padding.right,
        bottom: padding.bottom,
      );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: edge,
        child: BlocProvider.value(
          value: navigation,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppShell(
              pageFor: (tab) => switch (tab) {
                AppTab.library => const _Counter(),
                AppTab.editor => const Text('editor page'),
                AppTab.settings => const Text('settings page'),
              },
            ),
          ),
        ),
      ),
    );
    edgeEvents.add(barEdge);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('puts the tab capsule in a trailing vertical bar', (
    tester,
  ) async {
    await pumpShell(
      tester,
      barEdge: 'trailing',
      padding: const EdgeInsets.only(right: 46),
    );

    final rail = tester.getRect(find.byType(AppNavigationRail));
    expect(rail.center.dx, closeTo(890 - 46 / 2, 0.5));
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('uses a bottom navigation bar when there is no vertical bar', (
    tester,
  ) async {
    await pumpShell(tester, barEdge: 'unspecified');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(AppNavigationRail), findsNothing);
  });

  testWidgets('switches pages from the capsule and keeps them alive', (
    tester,
  ) async {
    await pumpShell(
      tester,
      barEdge: 'trailing',
      padding: const EdgeInsets.only(right: 46),
    );
    await tester.tap(find.text('count: 0'));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    expect(find.text('settings page'), findsOneWidget);

    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    expect(find.text('count: 1'), findsOneWidget);
  });
}
