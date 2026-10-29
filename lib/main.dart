import 'package:flutter/material.dart';

import 'app.dart';
import 'core/dependency_injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const DuoTabApp(home: SizedBox()));
}
