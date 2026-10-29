import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine/asset_server.dart';
import '../engine/engine_assets.dart';
import '../engine/engine_bridge.dart';
import '../engine/engine_host.dart';
import '../features/import/incoming_files_provider.dart';
import '../features/library/library_cubit.dart';
import '../features/playback/playback_cubit.dart';
import '../features/playback/practice_store.dart';
import '../features/score/score_cubit.dart';
import '../features/settings/settings_cubit.dart';
import '../presentation/shell/app_destinations.dart';
import '../presentation/shell/navigation_cubit.dart';
import 'duo/hinge_status_provider.dart';
import 'duo/vertical_bar_edge_provider.dart';
import 'storage/json_file.dart';

final getIt = GetIt.instance;

class AppDirectories {
  final Directory documents;

  const AppDirectories({required this.documents});
}

Future<void> setupDependencies() async {
  final documents = await getApplicationDocumentsDirectory();
  final support = await getApplicationSupportDirectory();
  await support.create(recursive: true);
  final settings = SettingsCubit(
    JsonFile(File(p.join(support.path, 'settings.json'))),
  );
  await settings.load();
  final practice = PracticeStore(
    JsonFile(File(p.join(support.path, 'practice.json'))),
  );
  final engineAssets = await extractEngineAssets(
    Directory(p.join((await getTemporaryDirectory()).path, 'engine')),
  );
  final server = await AssetServer.start(
    engineAssets: engineAssets,
    documents: documents,
  );
  final host = EngineHost(server.engineUri);

  final engine = EngineBridge(host.transport);
  host.onRestart = engine.restart;
  final library = LibraryCubit(documents: documents, engine: engine);
  final navigation = NavigationCubit();
  final score = ScoreCubit(engine: engine);
  final hinge = HingeStatusProvider();
  final playback = PlaybackCubit(engine: engine, hinge: hinge, score: score);

  getIt
    ..registerSingleton<AppDirectories>(AppDirectories(documents: documents))
    ..registerSingleton<AssetServer>(server)
    ..registerSingleton<EngineHost>(host)
    ..registerSingleton<EngineBridge>(engine)
    ..registerSingleton<LibraryCubit>(library)
    ..registerSingleton<ScoreCubit>(score)
    ..registerSingleton<PlaybackCubit>(playback)
    ..registerSingleton<PracticeStore>(practice)
    ..registerSingleton<SettingsCubit>(settings)
    ..registerSingleton<IncomingFilesProvider>(
      IncomingFilesProvider(
        documents: documents,
        onImported: (path) async {
          navigation.select(AppTab.editor);
          await Future.wait([library.refresh(), score.open(path)]);
        },
      ),
    )
    ..registerSingleton<VerticalBarEdgeProvider>(VerticalBarEdgeProvider())
    ..registerSingleton<HingeStatusProvider>(hinge)
    ..registerSingleton<NavigationCubit>(navigation);
}
