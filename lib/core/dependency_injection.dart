import 'package:get_it/get_it.dart';

import '../presentation/shell/navigation_cubit.dart';
import 'duo/hinge_status_provider.dart';
import 'duo/vertical_bar_edge_provider.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  getIt
    ..registerSingleton<VerticalBarEdgeProvider>(VerticalBarEdgeProvider())
    ..registerSingleton<HingeStatusProvider>(HingeStatusProvider())
    ..registerSingleton<NavigationCubit>(NavigationCubit());
}
