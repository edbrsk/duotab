import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/dependency_injection.dart';
import 'core/duo/vertical_bar_edge_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: getIt<VerticalBarEdgeProvider>()),
      ],
      child: const DuoTabApp(home: SizedBox()),
    ),
  );
}
