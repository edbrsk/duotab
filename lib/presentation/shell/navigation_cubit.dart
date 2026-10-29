import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_destinations.dart';

class NavigationCubit extends Cubit<AppTab> {
  NavigationCubit() : super(AppTab.library);

  void select(AppTab tab) => emit(tab);
}
