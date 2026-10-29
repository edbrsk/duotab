import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/dependency_injection.dart';
import 'core/duo/hinge_status_provider.dart';
import 'core/duo/vertical_bar_edge_provider.dart';
import 'features/editor/editor_cubit.dart';
import 'features/editor/song_saver.dart';
import 'features/library/library_cubit.dart';
import 'features/library/library_page.dart';
import 'features/playback/playback_cubit.dart';
import 'features/score/score_cubit.dart';
import 'features/score/score_page.dart';
import 'features/settings/licences.dart';
import 'features/settings/settings_cubit.dart';
import 'features/settings/settings_page.dart';
import 'presentation/shell/app_destinations.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/shell/fold_gate.dart';
import 'presentation/shell/navigation_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  registerBundledLicences(rootBundle);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: getIt<VerticalBarEdgeProvider>()),
        ChangeNotifierProvider.value(value: getIt<HingeStatusProvider>()),
        BlocProvider.value(value: getIt<NavigationCubit>()),
        BlocProvider.value(value: getIt<LibraryCubit>()),
        BlocProvider.value(value: getIt<ScoreCubit>()),
        BlocProvider.value(value: getIt<PlaybackCubit>()),
        BlocProvider.value(value: getIt<EditorCubit>()),
        BlocProvider.value(value: getIt<SettingsCubit>()),
      ],
      child: DuoTabApp(
        home: FoldGate(
          child: AppShell(
            pageFor: (tab) => switch (tab) {
              AppTab.library => LibraryPage(
                onOpen: (path) async {
                  getIt<NavigationCubit>().select(AppTab.editor);
                  await getIt<SongSaver>().flush();
                  await getIt<ScoreCubit>().open(path);
                },
                onNewSong: (options) async {
                  getIt<NavigationCubit>().select(AppTab.editor);
                  try {
                    await getIt<SongSaver>().createSong(options);
                  } on SongNotCreated catch (e) {
                    // The score page already shows the engine's error.
                    debugPrint('$e');
                  }
                },
              ),
              AppTab.editor => const ScorePage(),
              AppTab.settings => const SettingsPage(),
            },
          ),
        ),
      ),
    ),
  );
}
