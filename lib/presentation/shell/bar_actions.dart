import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_destinations.dart';

class BarAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const BarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
}

/// The actions each tab's page shows in the vertical bar, above the tabs.
class BarActions extends ChangeNotifier {
  final _actions = <AppTab, List<BarAction>>{};
  var _disposed = false;

  List<BarAction> of(AppTab tab) => _actions[tab] ?? const [];

  void set(AppTab tab, List<BarAction> actions) {
    // A page's last post-frame clear can land after the shell has gone.
    if (_disposed) return;
    final changed = !_looksSame(of(tab), actions);
    _actions[tab] = actions;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static BarActions? maybeOf(BuildContext context) =>
      Provider.of<BarActions?>(context, listen: false);

  static bool _looksSame(List<BarAction> a, List<BarAction> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].icon != b[i].icon || a[i].tooltip != b[i].tooltip) return false;
    }
    return true;
  }
}

class BarActionsFor extends StatefulWidget {
  final AppTab tab;
  final List<BarAction> actions;
  final Widget child;

  const BarActionsFor({
    required this.tab,
    required this.actions,
    required this.child,
    super.key,
  });

  @override
  State<BarActionsFor> createState() => _BarActionsForState();
}

class _BarActionsForState extends State<BarActionsFor> {
  BarActions? _bar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bar = BarActions.maybeOf(context);
  }

  @override
  void dispose() {
    final bar = _bar;
    final tab = widget.tab;
    final published = widget.actions;
    // Disposal happens mid-build of the parent, where notifying would throw.
    // A page rebuilt elsewhere in the tree has published its own by then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(bar?.of(tab), published)) bar?.set(tab, const []);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = _bar;
    final tab = widget.tab;
    final actions = widget.actions;
    // Notifying the bar mid-build would rebuild the shell during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) bar?.set(tab, actions);
    });
    return widget.child;
  }
}
