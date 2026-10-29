import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum AppTab { library, editor, settings }

class AppDestination {
  final AppTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppDestination({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

List<AppDestination> appDestinations(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    AppDestination(
      tab: AppTab.library,
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music,
      label: l10n.tabLibrary,
    ),
    AppDestination(
      tab: AppTab.editor,
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
      label: l10n.tabEditor,
    ),
    AppDestination(
      tab: AppTab.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: l10n.tabSettings,
    ),
  ];
}
