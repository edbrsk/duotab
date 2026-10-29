import 'package:get_it/get_it.dart';

import 'duo/vertical_bar_edge_provider.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  getIt.registerSingleton<VerticalBarEdgeProvider>(VerticalBarEdgeProvider());
}
