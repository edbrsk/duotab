import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/dependency_injection.dart';
import 'core/duo/hinge_status_provider.dart';
import 'core/duo/vertical_bar_edge_provider.dart';
import 'features/settings/settings_page.dart';
import 'presentation/shell/app_destinations.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/shell/fold_gate.dart';
import 'presentation/shell/navigation_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: getIt<VerticalBarEdgeProvider>()),
        ChangeNotifierProvider.value(value: getIt<HingeStatusProvider>()),
        BlocProvider.value(value: getIt<NavigationCubit>()),
      ],
      child: DuoTabApp(
        home: FoldGate(
          child: AppShell(
            pageFor: (tab) => switch (tab) {
              AppTab.library => const SizedBox(),
              AppTab.editor => const SizedBox(),
              AppTab.settings => const SettingsPage(),
            },
          ),
        ),
      ),
    ),
  );
}
