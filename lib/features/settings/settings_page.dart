import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.tabSettings,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
