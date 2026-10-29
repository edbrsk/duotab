import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../core/duo/vertical_bar_edge_provider.dart';
import '../widgets/app_navigation_rail.dart';
import 'app_destinations.dart';
import 'navigation_cubit.dart';

/// Every tab's page stays mounted so the Editor's engine web view keeps
/// running; tabs float in the vertical bar on iPhone Duo and sit at the
/// bottom elsewhere.
class AppShell extends StatelessWidget {
  final Widget Function(AppTab tab) pageFor;

  const AppShell({required this.pageFor, super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<NavigationCubit>().state;
    final navigation = context.read<NavigationCubit>();
    final pages = IndexedStack(
      index: current.index,
      children: [for (final tab in AppTab.values) pageFor(tab)],
    );

    final edge = VerticalBarEdgeProvider.edgeOf(context);
    if (edge == VerticalBarEdge.unspecified) {
      return Scaffold(
        body: pages,
        bottomNavigationBar: NavigationBar(
          selectedIndex: current.index,
          onDestinationSelected: (i) => navigation.select(AppTab.values[i]),
          destinations: [
            for (final d in appDestinations(context))
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    // The edge is directional; safe area insets are physical.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final barOnLeft = (edge == VerticalBarEdge.leading) != isRtl;
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: pages),
          Positioned(
            left: barOnLeft ? 0 : null,
            right: barOnLeft ? null : 0,
            bottom: padding.bottom + Spacing.sm,
            width: barOnLeft ? padding.left : padding.right,
            child: Center(
              child: AppNavigationRail(
                currentTab: current,
                onTap: navigation.select,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
