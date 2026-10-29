import 'dart:async';

import 'package:duotab/core/duo/hinge_status_provider.dart';
import 'package:duotab/l10n/app_localizations.dart';
import 'package:duotab/presentation/shell/fold_gate.dart';
import 'package:duotab/presentation/shell/folded_screen.dart';
import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('count: $_count'),
      );
}

void main() {
  late StreamController<dynamic> events;
  late HingeStatusProvider hinge;

  setUp(() {
    events = StreamController<dynamic>();
    hinge = HingeStatusProvider(hingeEvents: events.stream);
  });

  tearDown(() async {
    hinge.dispose();
    await events.close();
  });

  // The hinge stream delivers on a microtask, so the rebuild lands one frame later.
  Future<void> hingeMoves(WidgetTester tester, String status) async {
    events.add(status);
    await tester.pump();
    await tester.pump();
  }

  Widget gate(Widget child) => ChangeNotifierProvider.value(
        value: hinge,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FoldGate(child: child)),
        ),
      );

  testWidgets('shows the folded screen only while closed', (tester) async {
    await tester.pumpWidget(gate(const Text('app')));

    await hingeMoves(tester, 'closed');
    expect(find.text('Open your iPhone Duo to continue'), findsOneWidget);
    expect(find.text('app'), findsNothing);

    await hingeMoves(tester, 'partiallyOpen');
    expect(find.text('app'), findsOneWidget);
    expect(find.byType(FoldedScreen), findsNothing);
  });

  testWidgets('keeps app state across close and reopen', (tester) async {
    await tester.pumpWidget(gate(const _Counter()));
    await tester.tap(find.text('count: 0'));
    await tester.pump();

    await hingeMoves(tester, 'closed');
    await hingeMoves(tester, 'fullyOpen');

    expect(find.text('count: 1'), findsOneWidget);
  });
}
