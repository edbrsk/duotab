import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine/asset_server.dart';
import '../engine/engine_assets.dart';
import '../engine/engine_bridge.dart';
import '../engine/engine_host.dart';
import '../presentation/shell/navigation_cubit.dart';
import 'duo/hinge_status_provider.dart';
import 'duo/vertical_bar_edge_provider.dart';

final getIt = GetIt.instance;

class AppDirectories {
  final Directory documents;

  const AppDirectories({required this.documents});
}

Future<void> setupDependencies() async {
  final documents = await getApplicationDocumentsDirectory();
  final engineAssets = await extractEngineAssets(
    Directory(p.join((await getTemporaryDirectory()).path, 'engine')),
  );
  final server = await AssetServer.start(
    engineAssets: engineAssets,
    documents: documents,
  );
  final host = EngineHost(server.engineUri);

  getIt
    ..registerSingleton<AppDirectories>(AppDirectories(documents: documents))
    ..registerSingleton<AssetServer>(server)
    ..registerSingleton<EngineHost>(host)
    ..registerSingleton<EngineBridge>(EngineBridge(host.transport))
    ..registerSingleton<VerticalBarEdgeProvider>(VerticalBarEdgeProvider())
    ..registerSingleton<HingeStatusProvider>(HingeStatusProvider())
    ..registerSingleton<NavigationCubit>(NavigationCubit());
}
