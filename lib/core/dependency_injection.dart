import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine/asset_server.dart';
import '../engine/engine_assets.dart';
import '../engine/engine_bridge.dart';
import '../engine/engine_host.dart';
import '../features/editor/editor_cubit.dart';
import '../features/editor/owned_files.dart';
import '../features/editor/song_saver.dart';
import '../features/export/export_channel.dart';
import '../features/export/song_exporter.dart';
import '../features/import/incoming_files_provider.dart';
import '../features/library/library_cubit.dart';
import '../features/library/song_files.dart';
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
  final temporary = await getTemporaryDirectory();
  final engineAssets = await extractEngineAssets(
    Directory(p.join(temporary.path, 'engine')),
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
  final playback = PlaybackCubit(
    engine: engine,
    hinge: hinge,
    score: score,
    practice: practice,
    settings: settings,
  );

  final editor = EditorCubit(engine: engine, score: score);
  final owned = OwnedFiles(JsonFile(File(p.join(support.path, 'owned.json'))));
  final saver = SongSaver(
    documents: documents,
    engine: engine,
    score: score,
    owned: owned,
    onSaved: library.refresh,
  );
  editor.edited.listen((_) => saver.schedule());
  // iOS may end a hidden app without warning; save what is pending first.
  AppLifecycleListener(onHide: saver.flush, onInactive: saver.flush);

  getIt
    ..registerSingleton<AppDirectories>(AppDirectories(documents: documents))
    ..registerSingleton<AssetServer>(server)
    ..registerSingleton<EngineHost>(host)
    ..registerSingleton<EngineBridge>(engine)
    ..registerSingleton<LibraryCubit>(library)
    ..registerSingleton<ScoreCubit>(score)
    ..registerSingleton<PlaybackCubit>(playback)
    ..registerSingleton<EditorCubit>(editor)
    ..registerSingleton<SongSaver>(saver)
    ..registerSingleton<SongExporter>(
      SongExporter(
        engine: engine,
        score: score,
        channel: const ExportChannel(),
        temporary: temporary,
      ),
    )
    ..registerSingleton<SongFiles>(
      SongFiles(
        documents: documents,
        score: score,
        saver: saver,
        practice: practice,
        owned: owned,
      ),
    )
    ..registerSingleton<PracticeStore>(practice)
    ..registerSingleton<SettingsCubit>(settings)
    ..registerSingleton<IncomingFilesProvider>(
      IncomingFilesProvider(
        documents: documents,
        onImported: (path) async {
          navigation.select(AppTab.editor);
          await saver.flush();
          await Future.wait([library.refresh(), score.open(path)]);
        },
      ),
    )
    ..registerSingleton<VerticalBarEdgeProvider>(VerticalBarEdgeProvider())
    ..registerSingleton<HingeStatusProvider>(hinge)
    ..registerSingleton<NavigationCubit>(navigation);
}
