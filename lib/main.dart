import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/dependency_injection.dart';
import 'core/duo/hinge_status_provider.dart';
import 'core/duo/vertical_bar_edge_provider.dart';
import 'presentation/shell/fold_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: getIt<VerticalBarEdgeProvider>()),
        ChangeNotifierProvider.value(value: getIt<HingeStatusProvider>()),
      ],
      child: const DuoTabApp(home: FoldGate(child: SizedBox())),
    ),
  );
}
